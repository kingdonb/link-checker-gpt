LINKS_MUTEX = Thread::Mutex.new

class LinkAnalyzer
  SLICE_SIZE = 10

  def initialize(domain, masquerade_domain)
    @domain = domain
    @masquerade_domain = masquerade_domain
  end

  def analyze_links(sitemap_urls)
    links_data = []
    threads = []

    sitemap_urls.each_slice(SLICE_SIZE) do |slice|
      threads << Thread.new do
        slice.each do |url|
          begin
            puts "Visiting: #{url}"
            url = masquerade_url(url) if @masquerade_domain
            doc = Link.new(url, nil, @domain).download_and_store

            # Extracting all the links from the page
            doc.css('a').each do |link_element|
              link_href = link_element['href']
              # Skip links without href or with href set to '#'
              next if link_href.nil? || link_href.strip == '#'

              begin
              link = Link.new(url, link_element, @domain)
              rescue URI::InvalidURIError => e
                PRY_MUTEX.synchronize{binding.pry}
              end
              LINKS_MUTEX.synchronize do
                links_data << link
              end
            end
          rescue StandardError => e
            puts "Error downloading or analyzing URL #{url}: #{e.message}"
          end
        end
      end
    end

    threads.each(&:join)
    links_data
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
end
