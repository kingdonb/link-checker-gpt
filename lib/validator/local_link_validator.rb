require './lib/validator/base_link_validator'
require './lib/cache_helper'
require './lib/constants'

class LocalLinkValidator < BaseLinkValidator

  include Constants

  def validate
    target = nil
    retries = 0

    loop do
      @links_mutex.synchronize do
        return if @link.response_status && @link.response_status.to_i >= 400
        target = @link.target
      end

      # Check if the target URL is absolute
      break if URI.parse(target).host

      # If the maximum number of retries has been reached, return
      raise StandardError, "waiting for link to become absolute but it never did" if retries >= MAX_RETRIES

      # Sleep for a short duration and then retry
      sleep(SLEEP_DURATION)
      retries += 1
    end

    # Skip attempting to read cache for file types fetched with HEAD requests
    return if target.end_with?('.pdf', '.png', '.jpg')

    normalized_url = URI(target).normalize.to_s
    cache_path = CacheHelper.get_cache_path(normalized_url)

    doc = fetch_document_from_cache(normalized_url, cache_path)

    if valid_anchor?
      escaped = escaped_anchor
      @link.check_reference_intact!(escaped_anchor, doc)
    end
  end

  private

  def fetch_document_from_cache(normalized_url, cache_path)
    unless File.exist?(cache_path)
      # Might be a redirect. Attempt to follow it.
      doc, cache_path = @link.download_and_store
      # Return early if still not cached after attempting to follow the redirect
      return if doc.nil?
    end

    @links_mutex.synchronize do
      @parsed_docs_cache[normalized_url] ||= Nokogiri::HTML(File.read(cache_path))
    end
  end
end
