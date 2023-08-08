
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
def download_and_analyze_links(sitemap_urls)
  links_data = []
  cache_expiry_time = 3600 # 1 hour cache validity

  # Introducing concurrency using Threads
  threads = []

  sitemap_urls.each do |url|
    threads << Thread.new do
      puts "Visiting: #{url}"

      # Validate cache before downloading
      cache_path = "cache" + URI(url).path
      if File.exist?(cache_path) && (Time.now - File.mtime(cache_path)) < cache_expiry_time
        page_content = File.read(cache_path)
      else
        page_content = Net::HTTP.get(URI(url))

        # Save the content to a local cache
        FileUtils.mkdir_p(File.dirname(cache_path))
        File.write(cache_path, page_content)
      end

      doc = Nokogiri::HTML(page_content)

      # Using CSS selectors for better link extraction efficiency
      doc_links = doc.css('a[href]')

      doc_links.each do |link|
        link_href = link['href'].to_s.strip
        next if link_href.empty?

        # Create the full URL with the anchor fragment
        link_url_with_fragment = URI.join(url, link_href)

        # Create a version of the URL without the fragment for caching and network requests
        link_url = link_url_with_fragment.dup
        link_url.fragment = nil

        link_data = {
          link_source_file: url,
          link_target: link_url_with_fragment.to_s,
          link_type: determine_link_type(URI(url), link_url),
          anchor: !link_url_with_fragment.fragment.nil?,
          reference_intact: nil,
          response_status: nil,
          link_string: link_href,
          link_text: link.text.strip,
          link_line_no: link.line
        }

        links_data << link_data
      end
    end
  end

  # Wait for all threads to complete
  threads.each(&:join)

  links_data
end

# Function to validate links
def validate_links(links_data)
  # Set for storing already validated links to avoid redundant work
  validated_links = Set.new

  links_data.each do |link_data|
    link_target = link_data[:link_target]
    next if validated_links.include?(link_target)
    validated_links << link_target

    puts "Evaluating link: #{link_target}"

    begin
      case link_data[:link_type]
      when 'remote'
        # Make an HTTP request to the remote link and record the status
        response = Net::HTTP.get_response(URI(link_target))
        link_data[:response_status] = response.code

      when 'local', 'relative'
        # Check if the anchor reference is intact in the cached copy of the target page
        cache_path = "cache" + URI(link_target).path
        cache_path += "/index.html" if File.directory?(cache_path)

        if File.exist?(cache_path)
          doc = Nokogiri::HTML(File.read(cache_path))
          anchor = URI(link_target).fragment

          if anchor
            # Check if the anchor exists in the target page
            link_data[:reference_intact] = !!doc.at_css("a[name='#{anchor}'], ##{anchor}")
          end
        else
          puts "Cached copy not found for: #{link_target}"
        end
      end

    rescue StandardError => e
      puts "Error while evaluating link #{link_target}: #{e.message}"
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
domain = ARGV[0] || "fluxcd.io"
links_data = []

# Fetch sitemap and analyze links
begin
  sitemap_urls = fetch_sitemap(domain)
  puts "Fetched sitemap with #{sitemap_urls.count} URLs."

  download_and_analyze_links(sitemap_urls, links_data)
  puts "Downloaded and analyzed links for #{sitemap_urls.count} URLs."

  validate_links(links_data)
  puts "Validated #{links_data.count} links."

  # Generate the report with problematic links
  generate_report(links_data)
  puts "Report generated."

  # Display summary
  problematic_links = links_data.select { |link| (link[:link_type] == 'remote' && link[:response_status] != '200') || (link[:anchor] && !link[:reference_intact]) }
  puts "#{problematic_links.count} problematic links detected."

rescue StandardError => e
  puts "Error encountered: #{e.message}"
end
