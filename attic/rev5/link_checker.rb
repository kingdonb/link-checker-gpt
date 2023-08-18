
require 'nokogiri'
require 'net/http'
require 'uri'
require 'csv'
require 'fileutils'

# Function to fetch the sitemap
def fetch_sitemap(domain_name)
  sitemap_url = URI.join(domain_name, '/sitemap.xml')
  response = Net::HTTP.get_response(sitemap_url)
  
  if response.code != "200"
    raise "Unable to fetch sitemap from #{sitemap_url}"
  end
  
  sitemap = Nokogiri::XML(response.body).remove_namespaces!
  puts "Fetched sitemap with #{sitemap.xpath('//loc').size} URLs."
  sitemap
end

# Function to download content and analyze links
def download_and_analyze_links(domain_name, sitemap)
  links_data = []
  sitemap.xpath('//loc').each do |loc|
    page_url = loc.content
    puts "Visiting: #{page_url}"
    page_response = Net::HTTP.get_response(URI(page_url))
    next unless page_response.code == "200"
    
    doc = Nokogiri::HTML(page_response.body)
    # Save the content to local cache
    relative_path = URI(page_url).path
    relative_path = relative_path.empty? ? "/index.html" : relative_path
    relative_path += "/index.html" if relative_path.end_with?("/")
    cache_path = File.join("cache", relative_path)
    FileUtils.mkdir_p(File.dirname(cache_path)) unless Dir.exist?(File.dirname(cache_path))
    File.write(cache_path, page_response.body)
    doc.css('a').each_with_index do |link, index|
      link_href = link['href']
      next if link_href.nil?
      
      uri = URI(link_href) rescue next
      link_type = if uri.host && uri.host != domain_name
                    "remote"
                  elsif uri.path&.start_with?("/")
                    "local"
                  else
                    "relative"
                  end

      links_data << {
        link_source_file: page_url,
        link_target: link_href,
        remote_local_or_relative: link_type,
        anchor?: uri.fragment,
        reference_intact?: nil,
        response_status?: nil,
        link_string: link.to_s,
        link_text: link.text,
        link_line_no: link.line,
    cache_path: cache_path
      }
    end
  end
  
  puts "Analyzed #{links_data.size} links from the sitemap."
  links_data
end

# Function to validate links
def validate_links(links_data)
  remote_links = links_data.select { |link_info| link_info[:remote_local_or_relative] == "remote" }.size
  local_links = links_data.size - remote_links

  links_data.each do |link_info|
    puts "Evaluating link: #{link_info[:link_target]}"
    if link_info[:remote_local_or_relative] == "remote"
      response = Net::HTTP.get_response(URI(link_info[:link_target]))
      link_info[:response_status?] = response.code
    else
      # Using local cache to fetch the content
      relative_path = URI(link_info[:link_target]).path
      relative_path = relative_path.empty? ? "/index.html" : relative_path
      relative_path += "/index.html" if relative_path.end_with?("/")
      cache_path = File.join("cache", relative_path)
      target_content = File.read(cache_path) if File.exist?(cache_path)
      doc = Nokogiri::HTML(target_content)
      target_content = Net::HTTP.get(URI(link_info[:link_target]))
      doc = Nokogiri::HTML(target_content)
      if link_info[:anchor?]
        puts "Checking anchor: ##{link_info[:anchor?]}"
        link_info[:reference_intact?] = !!doc.at_css("a[name='#{link_info[:anchor?]}'], ##{link_info[:anchor?]}")
      end
    end
  end
  
  puts "Validated #{links_data.size} links: #{remote_links} remote and #{local_links} local."
  links_data
end

# Function to generate the report
def generate_report(links_data)
  invalid_links_count = 0
  CSV.open("report.csv", "wb") do |csv|
    csv << ["Link Source", "Link Target", "Type", "Anchor", "Reference Intact", "Response Status", "Link String", "Link Text", "Line Number"]
    links_data.each do |link_info|
      next if link_info[:remote_local_or_relative] == "remote" && link_info[:response_status?] == "200"
      next if link_info[:reference_intact?].nil? || link_info[:reference_intact?]
      
      invalid_links_count += 1
      csv << [
        link_info[:link_source_file],
        link_info[:link_target],
        link_info[:remote_local_or_relative],
        link_info[:anchor?],
        link_info[:reference_intact?],
        link_info[:response_status?],
        link_info[:link_string],
        link_info[:link_text],
        link_info[:link_line_no]
      ]
    end
  end
  puts "Total invalid links found: #{invalid_links_count}"
end

# Main execution
if __FILE__ == $0
  domain_name = ARGV[0] || "https://fluxcd.io"
  sitemap = fetch_sitemap(domain_name)
  links_data = download_and_analyze_links(domain_name, sitemap)
  validated_links = validate_links(links_data)
  generate_report(validated_links)
end
