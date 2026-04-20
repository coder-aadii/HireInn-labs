require "net/http"
require "json"
require "uri"
module Ai
  class ResumeAnalyzer
    class Error < StandardError; end

    ENDPOINT = "https://openrouter.ai/api/v1/chat/completions".freeze

    def call(job:, resume:)
      api_key = ENV["OPEN_ROUTER_API"].to_s
      model = ENV["OPEN_ROUTER_RESUME_MODEL"].presence || ENV["OPEN_ROUTER_AI_MODEL"].to_s

      raise Error, "OPEN_ROUTER_API is missing in .env." if api_key.empty?

      models = build_fallback_models(model)
      last_error = nil

      models.each do |candidate|
        payload = {
          model: candidate,
          response_format: { type: "json_object" },
          plugins: [{ id: "response-healing" }],
          temperature: 0.2,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt(job, resume) }
          ]
        }

        retries_remaining = 3
        wait_seconds = 2

        begin
          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = http_post(payload, api_key)
          elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
          Rails.logger.info("[ResumeAnalyzer] OpenRouter #{candidate} response in #{elapsed}s for resume ##{resume.id}")

          case response.code.to_i
          when 200
            parsed = JSON.parse(response.body)
            content = parsed.dig("choices", 0, "message", "content").to_s
            Rails.logger.info("[ResumeAnalyzer] Raw AI response: #{content.tr("\n", " ")[0, 1200]}")
            data = JSON.parse(extract_json(content))
            data = normalize_analysis(data, job, resume)
            match_score = data["match_percentage"].to_i.clamp(0, 100)
            Rails.logger.info("[ResumeAnalyzer] Final analysis for resume ##{resume.id} / job ##{job.id}: #{data.to_json}")
            return {
              match_score: match_score,
              analysis: data.merge("model" => candidate, "provider" => "openrouter", "response_id" => parsed["id"])
            }
          when 429
            raise Error, "Rate limited by OpenRouter."
          when 402
            raise Error, "OpenRouter credits exhausted (402)."
          else
            snippet = response.body.to_s[0, 300]
            raise Error, "AI request failed (#{response.code}). #{snippet}"
          end
        rescue Error => e
          if e.message == "Rate limited by OpenRouter." && retries_remaining.positive?
            Rails.logger.warn(
              "[ResumeAnalyzer] #{candidate} rate limited for resume ##{resume.id} / job ##{job.id}; retrying in #{wait_seconds}s (#{retries_remaining} retries left)"
            )
            sleep(wait_seconds)
            retries_remaining -= 1
            wait_seconds *= 2
            retry
          end

          last_error = e
          Rails.logger.warn("[ResumeAnalyzer] #{candidate} failed for resume ##{resume.id} / job ##{job.id}: #{e.message}")
          next
        end
      end

      raise(last_error || Error.new("AI request failed for all fallback models."))
    rescue JSON::ParserError
      raise Error, "AI response was not valid JSON."
    rescue StandardError => e
      raise e if e.is_a?(Error)

      Rails.logger.error("[ResumeAnalyzer] Unexpected error for resume ##{resume.id} / job ##{job.id}: #{e.class} - #{e.message}")
      raise Error, "Resume analysis failed: #{e.message}"
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
        - Never claim the candidate has software or technical skills unless those exact skills or very close synonyms appear in the resume text.
        - Do not mark a finance, sales, business development, operations, HR, or hospitality resume as a strong match for a software engineering role unless the resume clearly shows software development work.
        - If evidence is weak or generic, prefer lower scores and shorter matched_skills arrays.
      PROMPT
    end

    def user_prompt(job, resume)
      local = local_assessment(job, resume)

      <<~PROMPT
        JOB TITLE:

        JOB DESCRIPTION:

        JOB REQUIREMENTS:

        JOB SKILLS:

        RESUME EXTRACT:

        RESUME SKILLS:

        CORE JOB SKILLS:

        REQUIRED TECHNICAL SKILLS:

        HEURISTIC MATCHED SKILLS:

        HEURISTIC MISSING SKILLS:

        HEURISTIC TITLE OVERLAP:

        IMPORTANT:
        - Use the resume evidence only.
        - Keep the score conservative.
        - If heuristic missing skills are high or title overlap is 0, do not return a high score.

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

    def build_fallback_models(primary)
      [
        primary.presence,
        "liquid/lfm-2.5-1.2b-thinking:free",
        "lynn/soliloquy-v3",
        "openai/gpt-oss-20b:free",
        "google/gemma-4-27b-it:free",
        "mistralai/mistral-7b-instruct",
        "openrouter/auto"
      ].compact.uniq
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

    def normalize_analysis(data, job, resume)
      normalized = data.is_a?(Hash) ? data.dup : {}
      local = local_assessment(job, resume)

      ai_matched = normalize_list(normalized["matched_skills"])
      ai_missing = normalize_list(normalized["missing_skills"])

      normalized["matched_skills"] = merge_skill_lists(local["matched_skills"], ai_matched)
      normalized["missing_skills"] = merge_skill_lists(local["missing_skills"], ai_missing)
      normalized["match_percentage"] = reconcile_score(normalized["match_percentage"], local)
      normalized["experience_fit"] = reconcile_experience_fit(normalized["experience_fit"], normalized["match_percentage"], local)
      normalized["summary"] = reconcile_summary(normalized["summary"], local, job, resume)
      normalized["required_skills"] = local["required_skills"]
      normalized
    end

    def local_assessment(job, resume)
      resume_text = [
        resume.parsed_data["raw_excerpt"].to_s,
        Array(resume.skills).join(", "),
        Array(resume.education).join(", ")
      ].join("\n").downcase

      core_skills = extract_core_skills(job)
      required_skills = extract_required_skills(job)

      matched_core_skills = core_skills.select { |skill| skill_present?(resume_text, skill) }
      matched_required_skills = required_skills.select { |skill| skill_present?(resume_text, skill) }

      matched_skills = merge_skill_lists(matched_core_skills, matched_required_skills)
      missing_skills = required_skills - matched_required_skills

      title_keywords = extract_title_keywords(job.title)
      title_overlap = title_keywords.count { |keyword| resume_text.match?(keyword_match_pattern(keyword)) }

      generic_overlap = generic_keyword_overlap(job, resume_text)
      core_ratio = coverage_ratio(core_skills, matched_core_skills)
      required_ratio = coverage_ratio(required_skills, matched_required_skills)

      score = 18
      score += (core_ratio * 34).round
      score += (required_ratio * 28).round
      score += [title_overlap * 10, 20].min
      score += [generic_overlap * 4, 12].min

      if core_skills.any? && matched_core_skills.empty?
        score = [score, 40].min
      end

      if required_skills.any? && matched_required_skills.empty?
        score = [score, 28].min
      elsif required_skills.size >= 4 && matched_required_skills.size < 2
        score = [score, 52].min
      end

      if title_keywords.any? && title_overlap.zero?
        score = [score, 30].min
      end

      if technical_role?(job.title) && title_overlap.zero? && matched_skills.none? { |skill| technical_skill?(skill) }
        score = [score, 18].min
      end

      if resume.skills.blank? && resume.parsed_data["raw_excerpt"].to_s.blank?
        score = 0
      end

      {
        "core_skills" => core_skills,
        "required_skills" => required_skills,
        "matched_skills" => matched_skills,
        "missing_skills" => missing_skills,
        "title_overlap" => title_overlap,
        "generic_overlap" => generic_overlap,
        "matched_core_count" => matched_core_skills.size,
        "matched_required_count" => matched_required_skills.size,
        "score" => score.clamp(0, 100)
      }
    end

    def extract_core_skills(job)
      normalize_skill_collection(job.skills_required)
    end

    def extract_required_skills(job)
      candidates = []
      candidates.concat(normalize_list(job.skills_required))
      candidates.concat(extract_bullets(job.requirements))
      candidates.concat(extract_inline_markdown_section(job.description, "Required Technical Skills"))

      normalize_skill_collection(candidates)
    end

    def extract_bullets(text)
      text.to_s.split(/\r?\n/).filter_map do |line|
        stripped = line.strip
        next if stripped.empty?
        next unless stripped.start_with?("- ", "* ")

        stripped.sub(/\A[-*]\s+/, "")
      end
    end

    def extract_inline_markdown_section(text, heading)
      normalized = text.to_s.gsub("\r\n", "\n")
      match = normalized.match(/###\s+#{Regexp.escape(heading)}:\s*(.+?)(?=\n###\s|\z)/m)
      return [] unless match

      match[1].to_s.split(/\r?\n/).filter_map do |line|
        stripped = line.strip
        next unless stripped.start_with?("- ", "* ")

        stripped.sub(/\A[-*]\s+/, "")
      end
    end

    def normalize_list(value)
      Array(value).flat_map do |item|
        item.to_s.split(/\s*,\s*/)
      end.map { |item| item.to_s.strip }.reject(&:empty?).uniq
    end

    def normalize_skill_collection(values)
      normalize_list(values)
        .map { |skill| normalize_skill_phrase(skill) }
        .reject(&:empty?)
        .reject { |skill| sentence_like_requirement?(skill) }
        .reject { |skill| generic_requirement_phrase?(skill) }
        .uniq { |skill| skill.downcase }
        .first(12)
    end

    def normalize_skill_phrase(skill)
      skill.to_s
        .gsub(/\A(?:minimum of|minimum|at least|required|must have|ability to|knowledge of|experience with|experience in)\s+/i, "")
        .gsub(/\A\d+\+?\s*(?:years?|months?)\s+of\s+/i, "")
        .gsub(/\A(?:candidates with|candidate should have|candidate must have)\s+/i, "")
        .gsub(/\A(?:relevant )?experience\s+/i, "")
        .gsub(/[.]+$/, "")
        .squeeze(" ")
        .strip
    end

    def generic_requirement_phrase?(skill)
      phrase = skill.downcase
      return true if phrase.length < 3

      generic_phrases = [
        "strong communication", "communication skills", "interpersonal skills", "teamwork",
        "problem solving", "attention to detail", "ability to work", "positive attitude",
        "company values", "professionalism", "adaptability", "time management", "soft skills"
      ]

      generic_phrases.any? { |value| phrase.include?(value) }
    end

    def sentence_like_requirement?(skill)
      phrase = skill.to_s.strip
      return true if phrase.length > 45

      words = phrase.split(/\s+/)
      return true if words.length > 6
      return true if phrase.match?(/\b(?:apply|understanding|principles|adapt|challenges|candidate|experience can|learn quickly)\b/i)

      false
    end

    def extract_title_keywords(title)
      stopwords = %w[and or with for the a an in of to senior junior lead executive specialist associate]

      title.to_s.downcase.scan(/[a-z0-9+#.]+/).reject do |token|
        token.length < 3 || stopwords.include?(token)
      end.uniq
    end

    def generic_keyword_overlap(job, resume_text)
      content = [job.title, job.description, job.requirements].join(" ").downcase
      keywords = content.scan(/[a-z0-9+#.]{4,}/).uniq.first(24)
      keywords.count { |token| resume_text.match?(keyword_match_pattern(token)) }
    end

    def skill_present?(resume_text, skill)
      keyword_match_pattern(skill).match?(resume_text)
    rescue RegexpError
      resume_text.include?(skill.downcase)
    end

    def keyword_match_pattern(term)
      escaped = Regexp.escape(term.to_s.downcase.strip)
      /\b#{escaped.gsub("\\ ", "\\s+")}\b/i
    end

    def technical_role?(title)
      title.to_s.downcase.match?(/developer|engineer|software|frontend|backend|full[- ]?stack|programmer|qa|devops|data/)
    end

    def technical_skill?(skill)
      skill.to_s.downcase.match?(/ruby|rails|react|javascript|typescript|python|java|c\+\+|c#|sql|postgres|mysql|redis|api|docker|aws|node/)
    end

    def merge_skill_lists(primary, secondary)
      (Array(primary) + Array(secondary))
        .map { |value| value.to_s.strip }
        .reject(&:empty?)
        .uniq { |value| value.downcase }
        .first(10)
    end

    def coverage_ratio(total, matched)
      return 0.0 if total.blank?

      matched.size.to_f / total.size
    end

    def reconcile_score(ai_score, local)
      ai_value = ai_score.to_i
      local_value = local["score"].to_i
      matched_count = Array(local["matched_skills"]).size
      required_count = Array(local["required_skills"]).size
      title_overlap = local["title_overlap"].to_i

      final = [ai_value, local_value].max

      if required_count.positive? && matched_count.zero?
        final = [final, 28].min
      elsif required_count >= 4 && local["matched_required_count"].to_i < 2
        final = [final, 52].min
      end

      if title_overlap.zero?
        final = [final, 30].min
      end

      final.clamp(0, 100)
    end

    def reconcile_experience_fit(ai_fit, score, local)
      return "Low" if score.to_i < 40
      return "Medium" if score.to_i < 70
      return "Medium" if local["title_overlap"].to_i <= 1

      "High"
    end

    def reconcile_summary(ai_summary, local, job, resume)
      summary = ai_summary.to_s.strip
      matched = Array(local["matched_skills"])
      missing = Array(local["missing_skills"])
      candidate_name = resume.name.presence || "This candidate"

      if local["score"].to_i >= 55
        return "#{candidate_name} shows good alignment with #{job.title} through #{matched.first(5).join(', ')}#{missing.any? ? ", while still missing #{missing.first(3).join(', ')}." : "."}"
      end

      if local["score"].to_i <= 30
        reason = if missing.any?
          "missing key requirements such as #{missing.first(3).join(', ')}"
        else
          "showing limited evidence for the #{job.title} role"
        end
        return "#{candidate_name} appears to be a weak match because the resume shows limited direct alignment and is #{reason}."
      end

      return summary if summary.present?

      if matched.any?
        "#{candidate_name} shows meaningful alignment with #{job.title} through #{matched.first(5).join(', ')}."
      else
        "#{candidate_name} shows some transferable experience, but the match should be reviewed carefully against the role requirements."
      end
    end
  end
end
