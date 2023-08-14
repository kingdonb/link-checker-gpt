require './lib/fetch'
require './lib/link'
require './lib/validate'
require './lib/report'
require './lib/cache_helper'

class LinkChecker
  LINKS_DATA_FILE = "links_data.json"
  
  def initialize(domain, masquerade_domain, report_file)
    @domain = domain
    @masquerade_domain = masquerade_domain
    @report_file = report_file
  end

  def run
    fetch_sitemap
    download_and_analyze_links
    validate_links
    generate_report
  end

  private

  def fetch_sitemap
    fetcher = Fetch.new(@domain)
    @sitemap_urls = fetcher.urls
    puts "Fetched sitemap with #{@sitemap_urls.size} URLs."
  rescue => e
    puts "Error fetching sitemap: #{e.message}"
    exit
  end

  def download_and_analyze_links
    if File.exist?(LINKS_DATA_FILE)
      @links_data = JSON.parse(File.read(LINKS_DATA_FILE), symbolize_names: true)
      puts "Loaded links data from cache."
    else
      link_analyzer = LinkAnalyzer.new(@sitemap_urls, @domain)
      @links_data = link_analyzer.analyze
      File.write(LINKS_DATA_FILE, @links_data.to_json)
      puts "Links data saved to cache."
    end
  rescue => e
    puts "Error downloading and analyzing links: #{e.message}"
    exit
  end

  def validate_links
    validator = LinkValidator.new(@links_data, @domain, @masquerade_domain)
    validator.validate_links
  rescue => e
    puts "Error validating links: #{e.message}"
    exit
  end

  def generate_report
    reporter = ReportGenerator.new(@links_data, @report_file)
    reporter.generate
    puts "Report generated at #{@report_file}."
  rescue => e
    puts "Error generating report: #{e.message}"
  end
end
