require 'csv'
require 'logger'

logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = proc do |severity, _datetime, _progname, msg|
  # datefmt = datetime.strftime('%Y-%m-%dT%H:%M:%S.%6N')
  "#{severity[0].ljust(2)} #{msg}\n"
end

HEADER = ["Link Source", "Link Target", "Type", "Anchor?", "Reference Intact?", "Response Status", "Link String", "Link Text", "Line No."]

main_report = File.readlines('report.csv').map(&:strip)
preview_report = File.readlines('preview-report.csv').map(&:strip)

# Find the differences between the two reports
resolved_issues = main_report - preview_report
new_issues = preview_report - main_report

unresolved_issues = main_report & preview_report

# Write to the pr-summary.csv
CSV.open('pr-summary.csv', 'wb') do |csv|
  csv << HEADER
  new_issues.each do |issue|
    csv << issue.split(',')
  end
end

# Write to the baseline-unresolved.csv
CSV.open('baseline-unresolved.csv', 'wb') do |csv|
  csv << HEADER
  unresolved_issues.each do |issue|
    csv << issue.split(',')
  end
end

logger.info "Summary:"
logger.info "--------"

logger.info "Total issues in main site: #{main_report.count}"
logger.info "Total issues in preview site: #{preview_report.count}"

logger.info "Resolved issues: #{resolved_issues.count}"
logger.info "New issues: #{new_issues.count}"

# Check if there are any new issues and show top 3 problematic links
if new_issues.count > 0
  logger.warn "Fail: The preview site has introduced new issues!"
  logger.info "Issues introduced in the PR:"

  new_issues.each do |issue|
    data = issue.split(',')
    logger.info "Bad link: #{data[1]}"
    logger.info "Found on: #{data[0]}"
    # logger.info "Text: #{data[7]}"
    logger.info "link href: #{data[6]}"
    logger.info "---------"
  end

  logger.debug "Read pr-summary.csv for the full list of new issues."
  logger.warn "Please correct any bad links created by the preview build."
  logger.fatal "Exit (1)!"
  exit(1)
else
  logger.info "Pass: No new issues introduced in the preview site."
  exit(0)
end
