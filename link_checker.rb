
require 'nokogiri'
require 'net/http'
require 'csv'
require 'fileutils'
require 'json'
require 'open-uri'
require 'uri'
require 'pry'

PRY_MUTEX = Thread::Mutex.new
# PRY_MUTEX.synchronize{binding.pry}

# Function to fetch the sitemap
def fetch_sitemap(domain_name)
  sitemap_url = URI.join(domain_name, "/sitemap.xml")
  http = Net::HTTP.new(sitemap_url.host, sitemap_url.port)
  http.use_ssl = true if sitemap_url.scheme == "https"
  response = http.get(sitemap_url.path)

  # Follow redirects up to a maximum of 5 redirects
  max_redirects = 5
  while response.code.to_i.between?(300, 399) && max_redirects > 0
    sitemap_url = URI.join(sitemap_url, response['location'])
    response = http.get(sitemap_url.path)
    max_redirects -= 1
  end

  # Raise specific errors based on HTTP status code
  case response.code.to_i
  when 200
    # Successful response, continue
  when 404
    raise "Sitemap not found at #{sitemap_url}"
  when 500
    raise "Server error while fetching the sitemap from #{sitemap_url}"
  else
    raise "Failed to fetch sitemap from #{sitemap_url}. Status code: #{response.code}"
  end

  sitemap = Nokogiri::XML(response.body)
  sitemap.remove_namespaces!
  sitemap_urls = sitemap.xpath('//url/loc').map(&:text)
  sitemap_urls
end

# Helper method to determine the type of the link
def determine_link_type(domain_name, link_url)
  return 'remote' if link_url.host && link_url.host != domain_name.host
  return 'local' if link_url.host == domain_name.host
  'relative'
end

def get_cache_path(url)
  uri = URI(url)
  cache_path = "cache" + uri.path

  # If the path doesn't have a common file extension, treat it as a directory.
  unless cache_path.match(/\.(html|xml|json|txt|js|css|jpg|jpeg|png|gif)$/i)
    cache_path += "/index.html"
  end

  cache_path
end

# Function to download content and analyze links
def download_and_analyze_links(sitemap_urls, domain)
  links_data = []
  threads = []

  sitemap_urls.each_slice(SLICE_SIZE) do |slice|
    threads << Thread.new do
      slice.each do |url|
        begin
          uri = URI(url)

          # Skip mailto links
          # PRY_MUTEX.synchronize{binding.pry} if uri&.scheme == 'mailto'
          # next if uri&.scheme == 'mailto'

          # Ensure the URL is absolute
          unless uri.absolute?
            url = URI.join("https://#{domain}", url).to_s
          end

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
          doc.css('a').each do |link|
            link_data = {
              link_source_file: url,
              link_target: nil,
              link_type: nil,
              anchor: nil,
              reference_intact: nil,
              response_status: nil,
              link_string: link['href'],
              link_text: link.text.strip,
              link_line_no: link.line
            }

            # Handling relative links and converting them to absolute URLs
            link_url = URI.join(url, link['href'].to_s).to_s rescue next
            link_data[:link_target] = link_url

            # Determine if the link is remote, local, or relative
            if link_url.start_with?("http://", "https://")
              link_data[:link_type] = link_url.include?(domain) ? 'local' : 'remote'
            else
              link_data[:link_type] = 'relative'
            end

            # Check if the link has an anchor reference
            link_data[:anchor] = URI(link_url).fragment

            links_data << link_data
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

# Constants
MAX_THREADS = 10
MAX_RETRIES = 3

def validate_remote_link(link)
  # return unless link[:link_target]

  puts "Validating: #{link[:link_target]}"

  retries = 0

  begin
    response = Net::HTTP.get_response(URI(link[:link_target]))
    link[:response_status] = response.code
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    retries += 1
    retry if retries < MAX_RETRIES
    puts "Error after #{MAX_RETRIES} retries for link #{link[:link_target]}: #{e.message}"
    link[:response_status] = "Timeout"
  rescue SocketError => e
    puts "Network error for link #{link[:link_target]}: #{e.message}"
    link[:response_status] = "Network Error"
  rescue StandardError => e
    puts "Unexpected error for link #{link[:link_target]}: #{e.message}"
    link[:response_status] = "Error"
  end
end

def validate_local_link(link, parsed_docs_cache)
  normalized_url = URI(link[:link_target]).normalize.to_s
  cache_path = get_cache_path(normalized_url)

  return link[:response_status] = "Not Cached" unless File.exist?(cache_path)

  unless parsed_docs_cache[normalized_url]
    html_content = File.read(cache_path)
    parsed_docs_cache[normalized_url] = Nokogiri::HTML(html_content)
  end

  doc = parsed_docs_cache[normalized_url]
  anchor = link[:anchor]

  if valid_anchor?(anchor)
    escaped = escaped_anchor(anchor)
    link[:reference_intact] = !doc.css("[name=#{escaped}], ##{escaped}, [id=#{escaped}]").empty?
  end
# rescue Nokogiri::CSS::SyntaxError => e
#   PRY_MUTEX.synchronize{binding.pry}
end

def valid_anchor?(anchor)
  anchor && !anchor.empty? && !anchor.match(/[\\[\\]{}()*+?.,\\\\^$|#\\s]/)
end

def escaped_anchor(anchor)
  anchor.gsub(":", "\\:")
end

# Function to validate links
def validate_links(links_data, domain)
  parsed_docs_cache = {}

  # Separate remote links for parallel processing
  remote_links = links_data.select { |link| link[:link_type] == 'remote' }
  local_links = links_data - remote_links

  # Handle local links
  local_links.each do |link|
    next if link[:link_target] =~ /^mailto:/ # is not a local link
    validate_local_link(link, parsed_docs_cache)
  end

  # # Parallel processing for remote links
  # thread_pool = []
  # remote_links.each_slice(remote_links.size / MAX_THREADS + 1) do |link_slice|
  #   thread_pool << Thread.new do
  #     link_slice.each do |link|
  #       # don't validate anything for remote links
  #       # validate_remote_link(link)
  #     end
  #   end
  # end
  # thread_pool.each(&:join)  # Wait for all threads to finish
end

# Generates a CSV report with the problematic links data
def generate_report(links_data)
  CSV.open("report.csv", "wb") do |csv|
    csv << ["Link Source", "Link Target", "Type", "Anchor?", "Reference Intact?", "Response Status", "Link String", "Link Text", "Line No."]

    links_data.each do |link|
      if link[:link_type] == 'remote' && link[:response_status] != '200'
        csv << link.values
      elsif link[:anchor] && !link[:reference_intact]
        csv << link.values
      end
    end
  end
end

def fetch_sitemap_urls(domain)
  sitemap_uri = URI("https://#{domain}/sitemap.xml")
  sitemap = Nokogiri::XML(Net::HTTP.get(sitemap_uri))
  sitemap.remove_namespaces!
  urls = sitemap.xpath('//url/loc').map(&:text)
  raise "No URLs found in sitemap" if urls.empty?

  urls
end

# Constants
SLICE_SIZE = 10
CSV_FILE = ARGV[1] || "report.csv"
LINKS_DATA_FILE = "links_data.json"

# Default domain
domain = ARGV[0] || "fluxcd.io"

# Step 1: Fetch sitemap URLs
begin
  sitemap_urls = fetch_sitemap_urls(domain)
  puts "Fetched sitemap with #{sitemap_urls.size} URLs."
rescue => e
  puts "Error fetching sitemap: #{e.message}"
  exit
end

# Step 2: Download and analyze links
# Check if a cached links_data file exists
if File.exist?(LINKS_DATA_FILE)
  links_data = JSON.parse(File.read(LINKS_DATA_FILE), symbolize_names: true)
  puts "Loaded links data from cache."
else
  begin
    links_data = download_and_analyze_links(sitemap_urls, domain)
    # Save links_data to a file
    File.write(LINKS_DATA_FILE, links_data.to_json)
    puts "Links data saved to cache."
  rescue => e
    puts "Error downloading and analyzing links: #{e.message}"
    exit
  end
end

# Step 3: Validate each link
begin
  validate_links(links_data, domain)
rescue => e
  # binding.pry
  puts "Error validating links: #{e.message}"
  exit
end

# Step 4: Generate a CSV report
begin
  generate_report(links_data)
  puts "Report generated at #{CSV_FILE}."
rescue => e
  puts "Error generating report: #{e.message}"
end
