require './lib/validator/remote_link_validator'
require './lib/validator/local_link_validator'

class LinkValidator
  MAX_THREADS = 4

  def initialize(links_data, domain, masquerade_domain)
    @links_data = links_data.map do |link_data|
      link_data.dup.tap do |ld|
        ld[:link_target] = ld[:link_target].gsub(domain, masquerade_domain) if ld[:link_type] != 'remote'
      end
    end
    @parsed_docs_cache = {}
    @domain = domain
    @masquerade_domain = masquerade_domain
  end

  def validate_links
    # Separate remote links for parallel processing
    remote_links = @links_data.select { |link| link[:link_type] == 'remote' }
    local_links = @links_data - remote_links

    # Handle local links
    local_links.each do |link|
      next if link[:link_target] =~ /^mailto:/
      LocalLinkValidator.new(link, @parsed_docs_cache).validate
    end

    # Parallel processing for remote links
    # thread_pool = []
    # remote_links.each_slice(remote_links.size / MAX_THREADS + 1) do |link_slice|
    #   thread_pool << Thread.new do
    #     link_slice.each do |link|
    #       # don't validate anything for remote links
    #       # RemoteLinkValidator.new(link).validate
    #     end
    #   end
    # end
    # thread_pool.each(&:join)
  end
end
