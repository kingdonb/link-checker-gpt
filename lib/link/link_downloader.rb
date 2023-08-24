require './lib/constants'

class LinkDownloader
  attr_reader :source_file, :response_status

  include Constants

  def initialize(source_file)
    @source_file = source_file
    @response_status = nil
    @html_content = nil
  end

  def fetch_content
    return [parsed_content, cache_path] if content_cached?

    handle_redirects
    http_method == :head ? fetch_headers_only : fetch_full_content

    [parsed_content, cache_path]
  end

  private

  def content_cached?
    cache_path = CacheHelper.get_cache_path(@source_file)
    File.exist?(cache_path)
  end

  def handle_redirects
    redirect_count = 0

    while redirect_count < MAX_REDIRECTS
      response = Net::HTTP.get_response(URI(@source_file))
      if response.code.to_i.between?(300, 399)
        new_url = response['Location']
        # Cache the redirection reference for the original URL
        CacheHelper.write_to_cache(@source_file, "Redirect to #{new_url}", response.code)
        @source_file = new_url
        redirect_count += 1
      else
        break
      end
    end
  end

  def http_method
    @source_file.end_with?('.pdf', '.jpg', '.png') ? :head : :get
  end

  def fetch_headers_only
    response = Net::HTTP.start(URI(@source_file).host, URI(@source_file).port, use_ssl: true) do |http|
      http.head(URI(@source_file).path)
    end
    @response_status = response.code if response.code.to_i >= 400
    nil
  end

  def fetch_full_content
    response = Net::HTTP.get_response(URI(@source_file))
    @html_content = response.body
    @html_content.force_encoding('UTF-8')
    # Ensure the directory exists before writing the cache
    FileUtils.mkdir_p(File.dirname(cache_path))
    CacheHelper.write_to_cache(@source_file, @html_content, response.code)
    @response_status = response.code if response.code.to_i >= 400
  end

  def parsed_content
    Nokogiri::HTML(@html_content)
  end

  def cache_path
    CacheHelper.get_cache_path(@source_file)
  end
end
