class ReportGenerator
  HEADER = ["Link Source", "Link Target", "Type", "Anchor?", "Reference Intact?", "Response Status", "Link String", "Link Text", "Line No."]

  def initialize(links_data, filename = "report.csv")
    @links_data = links_data
    @filename = filename
  end

  def generate
    CSV.open(@filename, "wb") do |csv|
      csv << HEADER
      filter_links.each { |link| csv << link_data_array(link) }
    end
  end

  private

  def link_data_array(link)
    [
      link.source_file,
      link.target,
      link.type,
      link.anchor,
      link.reference_intact?,
      link.response_status,
      link.link_string,
      link.link_text,
      link.line_no
    ]
  end

  def filter_links
    @links_data.select do |link|
      link.type != 'remote' && (problematic_remote_link?(link) || problematic_anchor_link?(link))
    end
  end

  def problematic_remote_link?(link)
    link.type == 'remote' && link.response_status != '200'
  end

  def problematic_anchor_link?(link)
    link.anchor && !link.reference_intact?
  end
end

