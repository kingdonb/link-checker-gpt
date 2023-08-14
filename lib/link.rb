SLICE_SIZE = 10

class Link
  attr_accessor :source_file, :target, :type, :anchor,
                :response_status, :link_string, :link_text, :line_no

  def initialize(source_url, link_element, domain)
    @source_file = source_url
    @link_string = link_element['href']
    @link_text = link_element.text.strip
    @line_no = link_element.line
    @domain = domain

    # Use methods to set other attributes
    determine_type
    extract_anchor
    make_absolute
  end

  private

  def determine_type
    if @link_string.start_with?("http://", "https://")
      @type = @link_string.include?(@domain) ? 'local' : 'remote'
    else
      @type = 'relative'
    end
  end

  def extract_anchor
    @anchor = URI(@link_string).fragment
  end

  def make_absolute
    @target = URI.join(@source_file, @link_string).to_s
  rescue URI::InvalidURIError
    nil
  end
end

def download_and_analyze_links(sitemap_urls, domain)
  links_data = []
  threads = []

  sitemap_urls.each_slice(SLICE_SIZE) do |slice|
    threads << Thread.new do
      slice.each do |url|
        begin
          puts "Visiting: #{url}"
          cache_path = get_cache_path(url)
          unless File.exist?(cache_path)
            html_content = Net::HTTP.get(URI(url))
            FileUtils.mkdir_p(File.dirname(cache_path))
            File.write(cache_path, html_content)
          else
            html_content = File.read(cache_path)
          end

          doc = Nokogiri::HTML(html_content)

          # Extracting all the links from the page
          doc.css('a').each do |link_element|
            link_href = link_element['href']
            # Skip links without href or with href set to '#'
            next if link_href.nil? || link_href.strip == '#'

            link = Link.new(url, link_element, domain)
            links_data << link
        rescue StandardError => e
          puts "Error downloading or analyzing URL #{url}: #{e.message}"
        end
      end
    end
  end

  threads.each(&:join)
  links_data
end
