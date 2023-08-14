class ReportGenerator
  HEADER = ["Link Source", "Link Target", "Type", "Anchor?", "Reference Intact?", "Response Status", "Link String", "Link Text", "Line No."]
  FILE_NAME = "report.csv"

  def initialize(links_data)
    @links_data = links_data
  end

  def generate
    CSV.open(FILE_NAME, "wb") do |csv|
      csv << HEADER
      filter_links.each { |link| csv << link.values }
    end
  end

  private

  def filter_links
    @links_data.select do |link|
      problematic_remote_link?(link) || problematic_anchor_link?(link)
    end
  end

  def problematic_remote_link?(link)
    link[:link_type] == 'remote' && link[:response_status] != '200'
  end

  def problematic_anchor_link?(link)
    link[:anchor] && !link[:reference_intact]
  end
end

# Using the ReportGenerator class in the generate_report function
def generate_report(links_data)
  generator = ReportGenerator.new(links_data)
  generator.generate
end
