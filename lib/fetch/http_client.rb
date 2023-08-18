module Fetch
  class HttpClient
    attr_reader :http

    def initialize(url)
      @url = url
      @http = build_http_client
    end

    private

    def build_http_client
      http = Net::HTTP.new(@url.host, @url.port)
      http.use_ssl = true if @url.scheme == "https"
      http
    end
  end
end
