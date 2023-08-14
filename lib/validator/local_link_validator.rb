require './lib/validator/base_link_validator'

class LocalLinkValidator < BaseLinkValidator
  def validate
    normalized_url = URI(@link[:link_target]).normalize.to_s
    cache_path = get_cache_path(normalized_url)

    return link[:response_status] = "Not Cached" unless File.exist?(cache_path)

    unless @parsed_docs_cache[normalized_url]
      html_content = File.read(cache_path)
      @parsed_docs_cache[normalized_url] = Nokogiri::HTML(html_content)
    end

    doc = @parsed_docs_cache[normalized_url]
    anchor = link[:anchor]

    if valid_anchor?(anchor)
      escaped = escaped_anchor(anchor)
      link[:reference_intact] = !doc.css("[name=#{escaped}], ##{escaped}, [id=#{escaped}]").empty?
      # binding.pry unless link[:reference_intact]
    end
  rescue Nokogiri::CSS::SyntaxError => e
    # puts e.backtrace
    raise e
    # PRY_MUTEX.synchronize{binding.pry}
  end
end
