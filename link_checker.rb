
require 'nokogiri'
require 'net/http'
require 'uri'
require 'csv'
require 'fileutils'

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

# Function to download content and analyze links
def download_and_analyze_links(sitemap_urls, domain)
  links_data = []
  threads = []

  sitemap_urls.each_slice(SLICE_SIZE) do |slice|
    threads << Thread.new do
      slice.each do |url|
        begin
          # Ensure the URL is absolute
          unless URI(url).absolute?
            url = URI.join("https://#{domain}", url).to_s
          end

          puts "Visiting: #{url}"

          # Check if content already exists in cache
          cache_path = "cache" + URI(url).path
          cache_path += "/index.html" if cache_path.end_with?('/')
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

# Function to validate links
def validate_links(links_data, domain)
  parsed_docs_cache = {}

  links_data.each do |link|
    link_url = link[:link_target]
    puts "Evaluating link: #{link_url}"
    begin
      if link[:link_type] == 'remote'
        # Check the HTTP status for remote links
        response = Net::HTTP.get_response(URI(link_url))
        link[:response_status] = response.code
      else
        # Normalize the link URL
        normalized_url = URI(link_url).normalize.to_s

        # Check the anchor reference for local and relative links
        cache_path = "cache" + URI(normalized_url).path
        cache_path += "/index.html" if cache_path.end_with?('/')

        # Use the parsed doc from cache if available, otherwise parse the cached file
        unless parsed_docs_cache[normalized_url]
          html_content = File.read(cache_path)
          parsed_docs_cache[normalized_url] = Nokogiri::HTML(html_content)
        end
        doc = parsed_docs_cache[normalized_url]

        # Check for the existence of the anchor in a more inclusive way
        anchor = link[:anchor]
        if anchor
          link[:reference_intact] = !doc.css("[name=#{anchor}], ##{anchor}, [id=#{anchor}]").empty?
        end
      end
    rescue StandardError => e
      puts "Error validating link #{link_url}: #{e.message}"
      link[:response_status] = "unreachable" if link[:link_type] == 'remote'
    end
  end
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

# Main execution
require 'fileutils'
require 'json'

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
