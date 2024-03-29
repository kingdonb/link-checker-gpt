require './lib/validator/base_link_validator'
require './lib/cache_helper'

class LocalLinkValidator < BaseLinkValidator
  def validate
    return if @link.response_status && @link.response_status.to_i >= 400

    normalized_url = URI(@link.target).normalize.to_s
    cache_path = CacheHelper.get_cache_path(normalized_url)

    return @link.response_status = "Not Cached" unless File.exist?(cache_path)

    doc = nil
    @links_mutex.synchronize do
      unless @parsed_docs_cache[normalized_url]
        html_content = File.read(cache_path)
        @parsed_docs_cache[normalized_url] = Nokogiri::HTML(html_content)
      end
      doc = @parsed_docs_cache[normalized_url]
    end

    if valid_anchor?
      escaped = escaped_anchor
      @link.check_reference_intact!(escaped_anchor, doc)
    end
  # rescue Nokogiri::CSS::SyntaxError => e
  #   raise e
  end
end
