class ResumeParser
  class Error < StandardError; end

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    raise Error, "Resume not attached" unless @attachment.attached?

    text = extract_text
    {
      name: extract_name(text),
      email: extract_email(text),
      phone: extract_phone(text),
      skills: extract_skills(text),
      education: extract_education(text),
      raw_excerpt: text.to_s.slice(0, 1500)
    }
  rescue StandardError => e
    Rails.logger.warn("[ResumeParser] #{e.class}: #{e.message}")
    { error: e.message }
  end

  private

  def extract_text
    ensure_file_exists_patch!

    @attachment.open do |file|
      Yomu.new(file.path).text
    end
  end

  def ensure_file_exists_patch!
    return if File.respond_to?(:exists?)
    return unless File.respond_to?(:exist?)

    File.define_singleton_method(:exists?) { |path| exist?(path) }
  end

  def extract_email(text)
    text.to_s[/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i]
  end

  def extract_phone(text)
    text.to_s[/(\+?\d[\d\s().-]{7,}\d)/]
  end

  def extract_name(text)
    content = text.to_s
    name_line = content[/\bName:\s*([^\n]+)/i, 1]
    return name_line.to_s.strip if name_line.present?

    header_candidates = content.lines.first(12).map { |line| normalize_header_line(line) }.reject { |line| line.to_s.empty? }
    header_candidates.each do |candidate|
      return candidate if plausible_name?(candidate)
    end

    nil
  end

  def normalize_header_line(line)
    line.to_s
      .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      .gsub(/[[:space:]]+/, " ")
      .strip
      .sub(/\A[^A-Za-z]+/, "")
      .sub(/[^A-Za-z.\-'\s]+\z/, "")
      .strip
  end

  def plausible_name?(line)
    return false if line.blank?

    normalized = line.strip
    compact = normalized.downcase
    return false if compact.start_with?("resume", "curriculum vitae", "cv")
    return false if compact.include?("@")
    return false if compact.match?(/\d{3,}/)
    return false if compact.match?(%r{https?://|www\.})
    return false if compact.match?(/[+()\[\]_]/)

    blocked_terms = %w[
      developer engineer resume curriculum vitae profile summary objective contact email phone mobile
      github linkedin portfolio address india role experience skills education projects certifications
    ]
    return false if blocked_terms.any? { |term| compact.include?(term) }

    words = normalized.split(/\s+/)
    return false unless words.length.between?(2, 4)

    words.all? do |word|
      word.match?(/\A[A-Z][A-Za-z.'-]*\z/)
    end
  end

  def extract_skills(text)
    content = text.to_s
    section = extract_section(
      content,
      /(key skills|technical skills|skills|tools & platforms|tools and platforms|technologies|core competencies)/i
    )

    candidates = []
    candidates.concat(tokenize_skill_lines(section)) unless section.to_s.strip.empty?
    candidates.concat(scan_known_skills(content))

    candidates
      .map { |skill| normalize_skill(skill) }
      .reject(&:empty?)
      .uniq { |skill| skill.downcase }
      .first(20)
  end

  def extract_education(text)
    education_section = extract_section(text.to_s, /education/i)
    return [] if education_section.blank?

    lines = education_section
      .split(/\n/)
      .map { |s| s.strip.gsub(/\A[:\s•-]+/, "") }
      .reject(&:blank?)

    grouped = []
    buffer = []

    lines.each do |line|
      if education_boundary?(line) && buffer.any?
        grouped << buffer.join(" | ")
        buffer = [line]
      else
        buffer << line
      end
    end

    grouped << buffer.join(" | ") if buffer.any?
    grouped.first(8)
  end

  def extract_section(text, heading_pattern)
    lines = text.to_s.gsub("\r\n", "\n").split("\n")
    start_index = lines.index { |line| line.strip.match?(heading_pattern) }
    return "" unless start_index

    collected = []

    lines[(start_index + 1)..].to_a.each do |line|
      stripped = line.strip
      break if section_heading?(stripped) && collected.any?
      next if stripped.empty?

      collected << line
    end

    collected.join("\n").strip
  end

  def section_heading?(line)
    return false if line.to_s.strip.empty?

    normalized = line.strip
    return false if normalized.length < 3

    normalized.match?(/\A(?:professional summary|summary|experience|professional experience|education|projects|certifications|achievements|hobbies|contact|languages|internships?)\b/i)
  end

  def tokenize_skill_lines(section)
    section
      .split(/\n/)
      .map { |line| line.to_s.strip }
      .reject(&:empty?)
      .flat_map { |line| expand_skill_line(line) }
      .map { |entry| entry.to_s.sub(/\A[:\-\s]+/, "").strip }
      .reject(&:empty?)
      .flat_map { |entry| split_skill_entry(entry) }
  end

  def expand_skill_line(line)
    cleaned = line.to_s.gsub(/\A[•\-]+\s*/, "").strip
    return [] if cleaned.empty?
    return [] if narrative_skill_line?(cleaned)

    if cleaned.include?(":")
      label, values = cleaned.split(":", 2)
      return [] if values.blank?
      return [] if narrative_skill_line?(values)

      [values]
    else
      [cleaned]
    end
  end

  def split_skill_entry(entry)
    cleaned = entry.to_s
      .gsub(/\A[A-Za-z &\/]+\:\s*/, "")
      .gsub(/[()]/, ",")
      .strip
    return [] if cleaned.empty?
    return [] if narrative_skill_line?(cleaned)

    cleaned
      .split(%r{(?:/|,|\band\b)}i)
      .map(&:strip)
      .reject(&:empty?)
  end

  def normalize_skill(skill)
    value = skill.to_s.strip
    return "" if value.empty?
    return "" if value.length < 2
    return "" if narrative_skill_line?(value)
    return "" if value.match?(/\A\d+[%\w]*\z/) && !value.match?(/\A(?:c|c\+\+|c#)\z/i)
    return "" if value.match?(/\A(?:core)\z/i)

    normalized = value
      .gsub(/\A[-•]+\s*/, "")
      .gsub(/\A(?:web technologies & frameworks|tools & platforms|deployment|hosting|programming languages|core competencies|technical skills)\s*:\s*/i, "")
      .gsub(/\s+/, " ")
      .sub(/\Awith\s+/i, "")
      .sub(/\Abasic knowledge of\s+/i, "")
      .sub(/\Aproficiency in\s+/i, "")
      .sub(/\Aknowledge of\s+/i, "")
      .sub(/\Aand\s+/i, "")
      .sub(/\A[:\/,-]+\s*/, "")
      .sub(/[)\],]+\z/, "")
      .strip

    return "" if narrative_skill_line?(normalized)

    normalized
  end

  def scan_known_skills(text)
    known_skills = [
      "Ruby on Rails", "Ruby", "JavaScript", "TypeScript", "React", "Node.js", "Express.js",
      "MongoDB", "PostgreSQL", "MySQL", "Redis", "HTML", "CSS", "Sass", "Bootstrap",
      "Java", "Python", "C", "C++", "C#", "Git", "GitHub", "VS Code", "Postman",
      "Docker", "AWS", "Render", "Netlify", "REST API", "Agile", "Microsoft Office",
      "Excel", "Word", "PowerPoint", "Customer Service", "Communication", "Problem Solving"
    ]

    downcased_text = text.to_s.downcase

    known_skills.select do |skill|
      downcased_text.include?(skill.downcase)
    end
  end

  def narrative_skill_line?(text)
    value = text.to_s.strip
    return false if value.blank?
    return true if value.length > 48
    return true if value.include?(".")
    return true if value.match?(/\A(?:motivated|effective|eager|innovative|professional|passion|quick to|strong)\b/i)
    return true if value.match?(/\b(?:collaborative team|contribute|grow professionally|problem-solving mindset)\b/i)

    words = value.split(/\s+/)
    words.length > 5
  end

  def education_boundary?(line)
    value = line.to_s.strip
    return true if value.match?(/\A(?:master|bachelor|bachelors|mca|b\.sc|diploma|pg diploma)/i)
    return true if value.match?(/\A\d{4}\s*[-–]\s*\d{4}\b/)

    false
  end
end
