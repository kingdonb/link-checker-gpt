require './lib/fetch'
require './lib/link'
require './lib/validate'
require './lib/report'
require './lib/cache_helper'

class LinkChecker
  LINKS_DATA_FILE = "links_data.json"
  
  def initialize(domain, masquerade_domain, report_file, process_remote_links)
    @domain = domain
    @masquerade_domain = masquerade_domain
    @report_file = report_file
    @process_remote_links = process_remote_links
  end

  def run
    fetch_sitemap
    download_and_analyze_links
    validate_links
    generate_report
  end

  private

  def fetch_sitemap
    fetcher = SitemapFetcher.new(@domain, @masquerade_domain)
    @sitemap_urls = fetcher.fetch_sitemap_urls
    puts "Fetched sitemap with #{@sitemap_urls.size} URLs."
  rescue StandardError => e
    puts "Error fetching sitemap: #{e.message}"
    exit
  end

  def download_and_analyze_links
    if File.exist?(LINKS_DATA_FILE)
      # Loading from cache: Parse JSON data into Link objects
      links_data_hashes = JSON.parse(File.read(LINKS_DATA_FILE), symbolize_names: true)
      @links_data = links_data_hashes.map { |hash| Link.from_h(hash) }
      puts "Loaded links data from cache."
    else
      # Fetching fresh data: Use LinkAnalyzer to get Link objects and cache for future use
      analyzer = LinkAnalyzer.new(@domain, @masquerade_domain)
      @links_data = analyzer.analyze_links(@sitemap_urls)

      links_data_hashes = @links_data.map(&:to_h)
      File.write(LINKS_DATA_FILE, JSON.dump(links_data_hashes))

      puts "Links data saved to cache."
    end
  rescue StandardError => e
    puts "Error downloading and analyzing links: #{e.message}"
    exit
  end

  def validate_links
    validator = LinkValidator.new(@links_data, @domain, @masquerade_domain)
    @links_data = validator.validate_links
  rescue StandardError => e
    puts "Error validating links: #{e.message}"
    exit
  end

  def generate_report
    generator = ReportGenerator.new(@links_data, @report_file)
    generator.generate
    puts "Report generated at #{@report_file}."
  rescue StandardError => e
    puts "Error generating report: #{e.message}"
  end
end
