module JobsHelper
  def render_job_markdown(text)
    return "" if text.blank?

    normalized = text.to_s.gsub("\\n", "\n").gsub("\\t", "\t")
    lines = normalized.gsub("\r\n", "\n").split("\n")

    html = []
    in_list = false

    lines.each do |line|
      trimmed = line.strip

      if trimmed.start_with?("- ")
        unless in_list
          html << "<ul class=\"job-list\">"
          in_list = true
        end
        item = format_inline(trimmed.delete_prefix("- "))
        html << "<li>#{item}</li>"
        next
      end

      if in_list
        html << "</ul>"
        in_list = false
      end

      if trimmed.start_with?("### ")
        html << "<h4 class=\"job-h\">#{format_inline(trimmed.delete_prefix("### "))}</h4>"
      elsif trimmed.start_with?("## ")
        html << "<h3 class=\"job-h\">#{format_inline(trimmed.delete_prefix("## "))}</h3>"
      elsif trimmed.start_with?("# ")
        html << "<h2 class=\"job-h\">#{format_inline(trimmed.delete_prefix("# "))}</h2>"
      elsif trimmed.empty?
        html << "<div class=\"job-spacer\"></div>"
      else
        html << "<p class=\"job-p\">#{format_inline(trimmed)}</p>"
      end
    end

    html << "</ul>" if in_list

    html.join("\n").html_safe
  end

  private

  def format_inline(text)
    escaped = ERB::Util.html_escape(text)
    escaped.gsub(/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
  end
end
