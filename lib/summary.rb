require 'csv'

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

puts "Summary:"
puts "--------"

puts "Total issues in main site: #{main_report.count}"
puts "Total issues in preview site: #{preview_report.count}"

puts "\nResolved issues: #{resolved_issues.count}"
puts "New issues: #{new_issues.count}"

# Check if there are any new issues and show top 3 problematic links
if new_issues.count > 0
  puts "\nFail: The preview site has introduced new issues!"
  puts "\nTop 3 problematic links introduced in the PR:"

  new_issues.first(3).each do |issue|
    data = issue.split(',')
    puts "Link: #{data[1]}"
    puts "Found on: #{data[0]}"
    puts "---------"
  end

  puts "Please check pr-summary.csv for the full list of new issues."
  exit(1)
else
  puts "\nPass: No new issues introduced in the preview site."
  exit(0)
end
