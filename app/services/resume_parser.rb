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

    header_candidates = content.lines.first(12).map { |line| normalize_header_line(line) }.reject(&:blank?)
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
    skills_section = text.to_s.split(/skills/i, 2).last
    return [] if skills_section.blank?

    chunk = skills_section.split(/\n\n|\r\n\r\n/, 2).first.to_s
    chunk = chunk.sub(/^\s*[:\-–]/, "")
    chunk.split(/[,•\n]/).map { |s| s.strip.gsub(/\A[:\s]+/, "") }.reject(&:blank?).uniq.first(20)
  end

  def extract_education(text)
    education_section = text.to_s.split(/education/i, 2).last
    return [] if education_section.blank?

    chunk = education_section.split(/\n\n|\r\n\r\n/, 2).first.to_s
    chunk = chunk.sub(/^\s*[:\-–]/, "")
    chunk.split(/\n/).map { |s| s.strip.gsub(/\A[:\s]+/, "") }.reject(&:blank?).first(6)
  end
end
