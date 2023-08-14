class Link
  attr_accessor :source_file, :target, :type, :anchor,
                :response_status, :link_string, :link_text, :line_no, :reference_intact

  def initialize(source_url, link_element, domain)
    @source_file = source_url
    @domain = domain

    if link_element
      @link_string = link_element['href']
      @link_text = link_element.text.strip
      @line_no = link_element.line
      determine_type
      extract_anchor
    end

    make_absolute
  end

  def to_h
    {
      source_file: @source_file,
      target: @target,
      type: @type,
      anchor: @anchor,
      response_status: @response_status,
      link_string: @link_string,
      link_text: @link_text,
      line_no: @line_no,
      domain: @domain,
      reference_intact: @reference_intact
    }
  end

  def self.from_h(hash)
    link = self.new(hash[:source_file], nil, hash[:domain])
    link.target = hash[:target]
    link.type = hash[:type]
    link.anchor = hash[:anchor]
    link.response_status = hash[:response_status]
    link.link_string = hash[:link_string]
    link.link_text = hash[:link_text]
    link.line_no = hash[:line_no]
    link.reference_intact = hash[:reference_intact]
    link
  end

  def download_and_store
    cache_path = get_cache_path
    unless File.exist?(cache_path)
      html_content = Net::HTTP.get(URI(@source_file))
      FileUtils.mkdir_p(File.dirname(cache_path))
      File.write(cache_path, html_content)
    else
      html_content = File.read(cache_path)
    end

    Nokogiri::HTML(html_content)
  end

  def check_reference_intact!(escaped, doc)
    @reference_intact = !doc.css("[name=#{escaped}], ##{escaped}, [id=#{escaped}]").empty?
  end

  def reference_intact?
    @reference_intact
  end

  private

  def determine_type
    if @link_string.start_with?("http://", "https://")
      @type = @link_string.include?(@domain) ? 'local' : 'remote'
    else
      @type = 'relative'
    end
  end

  def extract_anchor
    @anchor = URI(@link_string).fragment
  rescue URI::InvalidURIError
    @anchor = URI(URI::Parser.new.escape(@link_string)).fragment
  end

  def make_absolute
    return unless @link_string
    @target = URI.join(@source_file, @link_string).to_s
  rescue URI::InvalidURIError
    @target = URI.join(@source_file, URI::Parser.new.escape(@link_string)).to_s
    nil
  end

  def get_cache_path
    uri = URI(@source_file)
    cache_path = "cache" + uri.path
    # If the path doesn't have a common file extension, treat it as a directory.
    unless cache_path.match(/\.(html|xml|json|txt|js|css|jpg|jpeg|png|gif)$/i)
      cache_path += "/index.html"
    end
    cache_path
  end
end

require './lib/link/link_analyzer'
