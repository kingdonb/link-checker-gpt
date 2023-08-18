require './lib/validator/remote_link_validator'
require './lib/validator/local_link_validator'

class LinkValidator
  MAX_THREADS = 4

  def initialize(links_data, domain, masquerade_domain, process_remote_links = false, logger)
    @links_data = links_data
    adjust_links_target(domain, masquerade_domain)

    @parsed_docs_cache = {}
    @parsed_docs_cache_mutex = Mutex.new
    @domain = domain
    @masquerade_domain = masquerade_domain
    @process_remote_links = process_remote_links
    @logger = logger
  end

  def validate_links
    handle_local_links
    handle_remote_links if @process_remote_links
    @links_data
  end

  private

  def adjust_links_target(domain, masquerade_domain)
    @links_data.each do |link|
      link.target.gsub!(domain, masquerade_domain) if link.type != 'remote'
    end
  end

  def handle_local_links
    @links_data.each do |link|
      next if link.type == 'remote' || link.target =~ /^mailto:/

      validator = LocalLinkValidator.new(link, @parsed_docs_cache, @parsed_docs_cache_mutex)
      validator.validate
    end
  end

  def handle_remote_links
    thread_pool = []
    remote_links = @links_data.select { |link| link.type == 'remote' }
    remote_links.each_slice(remote_links.size / MAX_THREADS + 1) do |link_slice|
      thread_pool << Thread.new do
        link_slice.each do |link|
          RemoteLinkValidator.new(link).validate
        end
      end
    end
    thread_pool.each(&:join)
  end
end
