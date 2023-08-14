
require 'nokogiri'
require 'net/http'
require 'csv'
require 'fileutils'
require 'json'
require 'open-uri'
require 'uri'
# require 'pry'

require './lib/link_checker'

# PRY_MUTEX = Thread::Mutex.new
# PRY_MUTEX.synchronize{binding.pry}

# Function to fetch the sitemap

# Helper method to determine the type of the link

# Function to download content and analyze links

# Generates a CSV report with the problematic links data

# Constants

# Main Execution
if __FILE__ == $0
  domain = ARGV[0] || "fluxcd.io"
  masq_domain = ARGV[1] || "fluxcd.io"
  report_file = ARGV[2] || "report.csv"
  checker = LinkChecker.new(domain, masq_domain, report_file)
  checker.run
end
