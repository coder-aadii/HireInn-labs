module MarkdownHelper
  def render_markdown(text)
    return "" if text.blank?

    lines = text.to_s.gsub("\r\n", "\n").split("\n")
    html_lines = []
    list_items = []

    flush_list = lambda do
      return if list_items.empty?
      html_lines << "<ul>#{list_items.join}</ul>"
      list_items.clear
    end

    lines.each do |line|
      if line.start_with?("- ")
        list_items << "<li>#{ERB::Util.html_escape(line[2..])}</li>"
        next
      end

      flush_list.call

      if line.start_with?("### ")
        html_lines << "<h4>#{ERB::Util.html_escape(line[4..])}</h4>"
      elsif line.start_with?("## ")
        html_lines << "<h3>#{ERB::Util.html_escape(line[3..])}</h3>"
      elsif line.start_with?("# ")
        html_lines << "<h2>#{ERB::Util.html_escape(line[2..])}</h2>"
      elsif line.strip.empty?
        html_lines << ""
      else
        escaped = ERB::Util.html_escape(line)
        escaped = escaped.gsub(/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
        html_lines << "<p>#{escaped}</p>"
      end
    end

    flush_list.call

    sanitize(html_lines.join("\n"), tags: %w[h2 h3 h4 p strong ul li], attributes: [])
  end

  def render_overview_markdown(text)
    return "" if text.blank?

    normalized = text.to_s.gsub("\r\n", "\n")
    overview_only = normalized.split(/^### Key Responsibilities:\s*$/).first.to_s.strip

    render_markdown(overview_only)
  end
end
