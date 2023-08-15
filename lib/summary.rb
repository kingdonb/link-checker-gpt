main_report = File.readlines('report.csv').map(&:strip)
preview_report = File.readlines('preview-report.csv').map(&:strip)

# Find the differences between the two reports
resolved_issues = main_report - preview_report
new_issues = preview_report - main_report

puts "Summary:"
puts "--------"

puts "Total issues in main site: #{main_report.count}"
puts "Total issues in preview site: #{preview_report.count}"

puts "\nResolved issues: #{resolved_issues.count}"
puts "New issues: #{new_issues.count}"

# Check if there are any new issues
if new_issues.count > 0
  puts "\nFail: The preview site has introduced new issues!"
  exit(1)
else
  puts "\nPass: No new issues introduced in the preview site."
  exit(0)
end
