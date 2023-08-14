class SitemapFetcher
  MAX_REDIRECTS = 5

  def initialize(domain_name)
    @sitemap_url = URI.join(domain_name, "/sitemap.xml")
    @http = build_http_client
  end

  def fetch
    response = fetch_content
    process_response(response)
  end

  private

  def build_http_client
    http = Net::HTTP.new(@sitemap_url.host, @sitemap_url.port)
    http.use_ssl = true if @sitemap_url.scheme == "https"
    http
  end

  def fetch_content
    response = @http.get(@sitemap_url.path)
    handle_redirection(response) while redirect?(response)
    response
  end

  def process_response(response)
    case response.code.to_i
    when 200
      # Successful response, continue
      sitemap = Nokogiri::XML(response.body)
      sitemap.remove_namespaces!
      sitemap.xpath('//url/loc').map(&:text)
    when 404
      raise HTTPError.new("Sitemap not found at #{@sitemap_url}")
    when 500
      raise HTTPError.new("Server error while fetching the sitemap from #{@sitemap_url}")
    else
      raise HTTPError.new("Failed to fetch sitemap from #{@sitemap_url}. Status code: #{response.code}")
    end
  end

  def redirect?(response)
    response.code.to_i.between?(300, 399)
  end

  def handle_redirection(response)
    raise RedirectionError, "Too many redirects" if MAX_REDIRECTS <= 0

    @sitemap_url = URI.join(@sitemap_url, response['location'])
    MAX_REDIRECTS -= 1
  end

  def fetch_sitemap_urls
    sitemap_uri = URI("https://#{@domain}/sitemap.xml")
    sitemap = Nokogiri::XML(Net::HTTP.get(sitemap_uri))
    sitemap.remove_namespaces!
    urls = sitemap.xpath('//url/loc').map(&:text)
    raise "No URLs found in sitemap" if urls.empty?

    urls
  end
end

class RedirectionError < StandardError; end
class HTTPError < StandardError; end

# Using the SitemapFetcher class in the fetch_sitemap function
def fetch_sitemap(domain_name)
  fetcher = SitemapFetcher.new(domain_name)
  fetcher.fetch
end
