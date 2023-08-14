class SitemapFetcher
  class RedirectionError < StandardError; end
  class HTTPError < StandardError; end

  MAX_REDIRECTS = 5

  def initialize(domain, masquerade_domain)
    @domain = domain
    @masquerade_domain = masquerade_domain
    @sitemap_url = URI.join("https://", domain, "sitemap.xml")
    @redirect_count = MAX_REDIRECTS
    @http = build_http_client
  end

  def fetch_sitemap_urls
    response = fetch_content
    urls = process_response(response)

    # Update the URLs to use the masquerade domain
    urls.map! do |url|
      url.gsub(@domain, @masquerade_domain)
    end

    raise "No URLs found in sitemap" if urls.empty?

    urls
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
      sitemap = Nokogiri::XML(response.body)
      sitemap.remove_namespaces!
      sitemap.xpath('//url/loc').map(&:text)
    when 404
      raise HTTPError, "Sitemap not found at #{@sitemap_url}"
    when 500
      raise HTTPError, "Server error while fetching the sitemap from #{@sitemap_url}"
    else
      raise HTTPError, "Failed to fetch sitemap from #{@sitemap_url}. Status code: #{response.code}"
    end
  end

  def redirect?(response)
    response.code.to_i.between?(300, 399)
  end

  def handle_redirection(response)
    raise RedirectionError, "Too many redirects" if @redirect_count <= 0

    @sitemap_url = URI.join(@sitemap_url, response['location'])
    @redirect_count -= 1
  end
end
