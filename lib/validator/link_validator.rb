require './lib/validator/remote_link_validator'
require './lib/validator/local_link_validator'

class LinkValidator
  MAX_THREADS = 4

  def initialize(links_data, domain, masquerade_domain, process_remote_links = false)
    @links_data = links_data.map do |link|
      link.dup.tap do |ld|
        ld.target = ld.target.gsub(domain, masquerade_domain) if ld.type != 'remote'
      end
    end
    @parsed_docs_cache = {}
    @domain = domain
    @masquerade_domain = masquerade_domain
    @process_remote_links = process_remote_links
  end

  def validate_links
    # Separate remote links for parallel processing
    remote_links = @links_data.select { |link| link.type == 'remote' }
    local_links = @links_data.reject { |link| link.type == 'remote' }

    # Handle local links
    local_links.each do |link|
      next if link.target =~ /^mailto:/
      LocalLinkValidator.new(link, @parsed_docs_cache).validate
    end

    if @process_remote_links
      # Parallel processing for remote links
      thread_pool = []
      remote_links.each_slice(remote_links.size / MAX_THREADS + 1) do |link_slice|
        thread_pool << Thread.new do
          link_slice.each do |link|
            RemoteLinkValidator.new(link).validate
          end
        end
      end
      thread_pool.each(&:join)
    end

    @links_data
  end
end
