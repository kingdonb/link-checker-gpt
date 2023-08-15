LINKS_MUTEX = Thread::Mutex.new

class LinkAnalyzer
  SLICE_SIZE = 10

  def initialize(domain, masquerade_domain)
    @domain = domain
    @masquerade_domain = masquerade_domain
  end

  def analyze_links(sitemap_urls)
    links_data = {}
    threads = []

    sitemap_urls.each_slice(SLICE_SIZE) do |slice|
      threads << Thread.new do
        slice.each do |url|
          # These links come from the sitemap, so they don't have any source yet
          link = ensure_link(links_data, url, url, nil)
          begin
            # Determine the source_url first
            domain_present = URI.parse(url).host.nil? ? false : true

            if domain_present
              source_url = masquerade_url(url) if @masquerade_domain
            else
              source_url = URI.join(@masquerade_domain, url).to_s
            end

            base_url, fragment = url.split('#', 2)
            fragment = URI::Parser.new.escape(fragment) if fragment
            full_url = fragment ? "#{base_url}##{fragment}" : base_url

            puts "Visiting: #{full_url}"
            doc = link.download_and_store

            # Extracting all the links from the page
            doc.css('a').each do |link_element|
              link_href = link_element['href']
              # Skip links without href or with href set to '#'
              next if link_href.nil? || link_href.strip == '#'

              # Splitting the base URL and fragment for proper handling
              base_url, fragment = link_href.split('#', 2)
              fragment = URI::Parser.new.escape(fragment) if fragment

              # Combine the base URL with the original URL and append the fragment if present
              joined_url = URI.join(url, base_url).to_s
              target_url = fragment ? "#{joined_url}##{fragment}" : joined_url

              link = ensure_link(links_data, source_url, target_url, link_element)
            end
          rescue StandardError => e

            link.response_status = "Error: #{e.message}"
            puts "Error downloading or analyzing URL #{url}: #{e.message}"
          end
        end
      end
    end

    threads.each(&:join)
    links_data.values
  end

  private

  def masquerade_url(url)
    uri = URI(url)
    if uri.host == @domain
      uri.host = @masquerade_domain
      uri.to_s
    else
      url
    end
  end

  def ensure_link(links_data, url, link_element)
    LINKS_MUTEX.synchronize do
      # Use both the target URL and source URL as the key to ensure uniqueness
      key = "#{source_url}::#{target_url}"
      links_data[key] ||= Link.new(source_url, link_element)
      links_data[key]
    end
  end
end
