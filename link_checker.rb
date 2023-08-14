
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

def parse_str_false(str)
  false if str =~ /^(false|f|no|n|off|0)$/i
end
def parse_str_true(str)
  true if str =~ /^(true|t|yes|y|on|1)$/i
end
def parse_boolean(str)
  parse_str_false("false") || parse_str_true("false")
end

# Main Execution
if __FILE__ == $0
  domain = ARGV[0] || "fluxcd.io"
  masq_domain = ARGV[1] || "fluxcd.io"
  report_file = ARGV[2] || "report.csv"
  remote_links = parse_boolean(ARGV[3]) || false

  checker = LinkChecker.new(domain, masq_domain, report_file, remote_links)
  checker.run
end
