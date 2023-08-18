module URLHelper
  def self.make_absolute(base_url, relative_url)
    return relative_url if relative_url.nil?

    begin
      URI.join(base_url, relative_url).to_s
    rescue URI::InvalidURIError
      URI.join(base_url, URI::Parser.new.escape(relative_url)).to_s
    end
  end

  def self.extract_fragment(url)
    return nil unless url

    begin
      URI(url).fragment
    rescue URI::InvalidURIError
      URI(URI::Parser.new.escape(url)).fragment
    end
  end
end
