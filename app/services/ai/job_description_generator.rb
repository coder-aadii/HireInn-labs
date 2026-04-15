require "net/http"
require "json"

module Ai
  class JobDescriptionGenerator
    class Error < StandardError; end

    ENDPOINT = "https://openrouter.ai/api/v1/chat/completions".freeze

    def call(title:, company_name:, location:, employment_type:, experience_min:)
      raise Error, "Job title is required for AI generation." if title.to_s.strip.empty?

      api_key = ENV["OPEN_ROUTER_API"].to_s
      model = ENV["OPEN_ROUTER_AI_MODEL"].to_s

      raise Error, "OPEN_ROUTER_API is missing in .env." if api_key.empty?

      models = build_fallback_models(model)
      last_error = nil

      models.each do |candidate|
        payload = {
          model: candidate,
          response_format: { type: "json_object" },
          plugins: [{ id: "response-healing" }],
          temperature: 0.7,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt(title, company_name, location, employment_type, experience_min) }
          ]
        }

        retries = 3

        begin
          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = http_post(payload, api_key)
          elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
          Rails.logger.info("[AI JD] OpenRouter #{candidate} response in #{elapsed}s")

          case response.code.to_i
          when 200
            parsed = JSON.parse(response.body)
            content = parsed.dig("choices", 0, "message", "content").to_s
            data = parse_json(content)

            description_markdown = data["description_markdown"].to_s
            description_markdown = build_full_markdown(
              description_markdown,
              title: title,
              company_name: company_name,
              location: location,
              employment_type: employment_type,
              role_overview: data["role_overview"],
              responsibilities: data["responsibilities"],
              requirements: data["requirements"],
              benefits: data["benefits"]
            )

            return {
              description_markdown: description_markdown,
              responsibilities: data["responsibilities"],
              requirements: data["requirements"],
              benefits: data["benefits"],
              skills: data["skills"],
              metadata: {
                model: candidate,
                provider: "openrouter",
                response_id: parsed["id"]
              }
            }
          when 429
            raise Error, "Rate limited by OpenRouter."
          when 402
            raise Error, "OpenRouter credits exhausted (402)."
          else
            snippet = response.body.to_s[0, 300]
            raise Error, "AI request failed (#{response.code}). #{snippet}"
          end
        rescue Error, JSON::ParserError => e
          retries -= 1
          last_error = e.is_a?(Error) ? e : Error.new("AI response was not valid JSON. Try again.")
          Rails.logger.warn("[AI JD] #{candidate} failed: #{last_error.message}")

          if retries.positive?
            sleep(2 ** (3 - retries))
            retry
          end
        end
      rescue JSON::ParserError => e
        last_error = Error.new("AI response was not valid JSON. Try again.")
        Rails.logger.warn("[AI JD] #{candidate} failed: #{e.message}")
        next
      rescue Error => e
        last_error = e
        Rails.logger.warn("[AI JD] #{candidate} failed: #{e.message}")
        next
      end

      raise last_error || Error, "AI request failed for all fallback models."
    rescue JSON::ParserError
      raise Error, "AI response was not valid JSON. Try again."
    rescue KeyError => e
      raise Error, "AI response missing field: #{e.message}"
    rescue Error => e
      Rails.logger.error("[AI JD] #{e.message}")
      raise
    end

    private

    def system_prompt
      "You are an expert HR copywriter. Return only valid JSON with keys: description_markdown, responsibilities (array), requirements (array), benefits (array), skills (array). No extra text. The description_markdown MUST include all sections: Job Title line, Company, Location, Employment Type, Role Overview, Key Responsibilities, Required Technical Skills and Experience Levels, Preferred Qualifications and Nice-to-Haves. Provide at least 6 bullets for responsibilities, 6 for required skills/experience, and 5 for preferred qualifications."
    end

    def user_prompt(title, company_name, location, employment_type, experience_min)
      <<~PROMPT
        Create a premium job description in the following markdown format.
        Return ONLY valid JSON with keys:
        - description_markdown (string, full markdown below)
        - role_overview (string paragraph)
        - responsibilities (array, 6-8 bullets)
        - requirements (array, 6-8 bullets)
        - benefits (array, 5-7 bullets for preferred qualifications)
        - skills (array, 6-10 skills)

        ## Job Title: <title>
        **Company:** <company>
        **Location:** <location>
        **Employment Type:** <employment type>

        ### Role Overview:
        <one paragraph>

        ### Key Responsibilities:
        - ...

        ### Required Technical Skills and Experience Levels:
        - ...

        ### Preferred Qualifications and Nice-to-Haves:
        - ...

        Input:
        - Title: #{title}
        - Company: #{company_name.presence || "Confidential"}
        - Location: #{location.presence || "Remote"}
        - Employment Type: #{employment_type.presence || "Full-time"}
        - Minimum Experience: #{experience_min.present? ? "#{experience_min}+ years" : "Not specified"}

        Make the content feel modern, confident, and enterprise-ready.
        Ensure the markdown includes all sections and is long-form.
      PROMPT
    end

    def http_post(payload, api_key)
      uri = URI(ENDPOINT)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request["HTTP-Referer"] = "http://localhost"
      request["X-Title"] = "HireInn Labs"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 60
        http.request(request)
      end

      response
    end

    def parse_json(content)
      cleaned = clean_json(content)
      JSON.parse(cleaned)
    end

    def clean_json(text)
      raise Error, "Empty AI response." if text.nil? || text.strip.empty?

      cleaned = text.strip
      if cleaned.start_with?("```")
        cleaned = cleaned.lines[1..-2].join
      end

      extracted = extract_json_object(cleaned)
      return extracted if extracted

      cleaned
    end

    def extract_json_object(text)
      start = text.index("{")
      finish = text.rindex("}")
      return if start.nil? || finish.nil? || finish <= start

      text[start..finish]
    end

    def build_fallback_models(primary)
      [
        primary.presence,
        "liquid/lfm-2.5-1.2b-thinking:free",
        "lynn/soliloquy-v3",
        "openai/gpt-oss-20b:free",
        "google/gemma-4-31b-it:free",
        "mistralai/mistral-7b-instruct",
        "openrouter/free"
      ].compact.uniq
    end

    def build_full_markdown(existing, title:, company_name:, location:, employment_type:, role_overview:, responsibilities:, requirements:, benefits:)
      normalized = existing.to_s
      return normalized if normalized.include?("### Key Responsibilities") && normalized.include?("### Required Technical Skills")

      overview = role_overview.presence || extract_overview_from(existing) || "Add a concise role overview."
      responsibilities_list = Array(responsibilities).presence || []
      requirements_list = Array(requirements).presence || []
      benefits_list = Array(benefits).presence || []

      <<~MD.strip
        ## Job Title: #{title}
        **Company:** #{company_name.presence || "Confidential"}
        **Location:** #{location.presence || "Remote"}
        **Employment Type:** #{employment_type.presence || "Full-time"}

        ### Role Overview:
        #{overview}

        ### Key Responsibilities:
        #{bullet_lines(responsibilities_list)}

        ### Required Technical Skills and Experience Levels:
        #{bullet_lines(requirements_list)}

        ### Preferred Qualifications and Nice-to-Haves:
        #{bullet_lines(benefits_list)}
      MD
    end

    def extract_overview_from(text)
      match = text.to_s.split("### Role Overview:").last
      return if match.blank?
      match.to_s.split("###").first.to_s.strip.presence
    end

    def bullet_lines(items)
      return "- Add details here." if items.blank?
      items.map { |item| "- #{item}" }.join("\n")
    end
  end
end
