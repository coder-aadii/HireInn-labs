require "net/http"
require "json"
require "uri"

module Ai
  class ResumeAnalyzer
    class Error < StandardError; end

    ENDPOINT = "https://openrouter.ai/api/v1/chat/completions".freeze

    def call(job:, resume:)
      api_key = ENV["OPEN_ROUTER_API"].to_s
      model = ENV["OPEN_ROUTER_AI_MODEL"].to_s

      raise Error, "OPEN_ROUTER_API is missing in .env." if api_key.empty?

      payload = {
        model: model.presence || "openrouter/auto",
        response_format: { type: "json_object" },
        temperature: 0.2,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt(job, resume) }
        ]
      }

      response = http_post(payload, api_key)
      case response.code.to_i
      when 200
        parsed = JSON.parse(response.body)
        content = parsed.dig("choices", 0, "message", "content").to_s
        data = JSON.parse(extract_json(content))
        match_score = data["match_percentage"].to_i.clamp(0, 100)
        {
          match_score: match_score,
          analysis: data.merge("model" => payload[:model], "provider" => "openrouter", "response_id" => parsed["id"])
        }
      when 429
        raise Error, "Rate limited by OpenRouter."
      when 402
        raise Error, "OpenRouter credits exhausted (402)."
      else
        raise Error, "AI request failed (#{response.code})."
      end
    rescue JSON::ParserError
      raise Error, "AI response was not valid JSON."
    end

    private

    def system_prompt
      <<~PROMPT
        You are a strict HR matching engine.
        Return ONLY valid JSON with keys:
        match_percentage (0-100),
        matched_skills (array),
        missing_skills (array),
        experience_fit (one of: "Low", "Medium", "High"),
        summary (string).

        Scoring rules:
        - If the resume domain is clearly unrelated to the job role, cap match_percentage at 30.
        - If required core skills are missing, cap at 50.
        - Only give 80+ if the resume shows strong, direct experience in the same role or domain.
        - Do NOT infer skills that are not explicitly present.
        - Use conservative scoring by default.
      PROMPT
    end

    def user_prompt(job, resume)
      <<~PROMPT
        JOB TITLE:
        #{job.title}

        JOB DESCRIPTION:
        #{job.description.to_s}

        JOB REQUIREMENTS:
        #{job.requirements.to_s}

        JOB SKILLS:
        #{Array(job.skills_required).join(", ")}

        RESUME EXTRACT:
        #{resume.parsed_data["raw_excerpt"].to_s}

        RESUME SKILLS:
        #{Array(resume.skills).join(", ")}

        Determine match quality and return JSON only.
      PROMPT
    end

    def http_post(payload, api_key)
      uri = URI(ENDPOINT)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request["HTTP-Referer"] = app_referer
      request["X-Title"] = "HireInn Labs"
      request.body = JSON.generate(payload)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 60
        http.request(request)
      end
    end

    def app_referer
      host = ENV["APP_HOST"].presence || "localhost:3000"
      protocol = ENV["APP_PROTOCOL"].presence || "http"
      normalized_host = host.sub(/\Ahttps?:\/\//, "")
      URI("#{protocol}://#{normalized_host}").to_s
    end

    def extract_json(text)
      cleaned = text.to_s.strip
      if cleaned.start_with?("```")
        cleaned = cleaned.lines[1..-2].join
      end

      start = cleaned.index("{")
      finish = cleaned.rindex("}")
      return "{}" if start.nil? || finish.nil? || finish <= start

      cleaned[start..finish]
    end
  end
end
