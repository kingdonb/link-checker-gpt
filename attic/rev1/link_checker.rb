#!/usr/bin/env ruby

require 'nokogiri'
require 'net/http'
require 'uri'
require 'csv'

# Function to fetch the sitemap
def fetch_sitemap(domain_name)
  sitemap_url = URI.join(domain_name, '/sitemap.xml')
  response = Net::HTTP.get_response(sitemap_url)
  
  if response.code != "200"
    raise "Unable to fetch sitemap from #{sitemap_url}"
  end
  
  Nokogiri::XML(response.body)
end

# Function to download content and analyze links
def download_and_analyze_links(domain_name, sitemap)
  links_data = []
  sitemap.xpath('//loc').each do |loc|
    page_url = loc.content
    page_response = Net::HTTP.get_response(URI(page_url))
    next unless page_response.code == "200"
    
    doc = Nokogiri::HTML(page_response.body)
    doc.css('a').each_with_index do |link, index|
      link_href = link['href']
      next if link_href.nil?
      
      uri = URI(link_href) rescue next
      link_type = if uri.host && uri.host != domain_name
                    "remote"
                  elsif uri.path.start_with?("/")
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
        link_line_no: link.line
      }
    end
  end
  
  links_data
end

# Function to validate links
def validate_links(links_data)
  links_data.each do |link_info|
    if link_info[:remote_local_or_relative] == "remote"
      response = Net::HTTP.get_response(URI(link_info[:link_target]))
      link_info[:response_status?] = response.code
    else
      # Assuming local cache isn't implemented yet, so we'll fetch fresh content
      target_content = Net::HTTP.get(URI(link_info[:link_target]))
      doc = Nokogiri::HTML(target_content)
      if link_info[:anchor?]
        link_info[:reference_intact?] = !!doc.at_css("a[name='#{link_info[:anchor?]}'], ##{link_info[:anchor?]}")
      end
    end
  end
  
  links_data
end

# Function to generate the report
def generate_report(links_data)
  CSV.open("report.csv", "wb") do |csv|
    csv << ["Link Source", "Link Target", "Type", "Anchor", "Reference Intact", "Response Status", "Link String", "Link Text", "Line Number"]
    links_data.each do |link_info|
      next if link_info[:remote_local_or_relative] == "remote" && link_info[:response_status?] == "200"
      next if link_info[:reference_intact?].nil? || link_info[:reference_intact?]
      
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
end

# Main execution
if __FILE__ == $0
  domain_name = ARGV[0] || "https://fluxcd.io"
  sitemap = fetch_sitemap(domain_name)
  links_data = download_and_analyze_links(domain_name, sitemap)
  validated_links = validate_links(links_data)
  generate_report(validated_links)
end
