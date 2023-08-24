require './lib/cache_helper'
require './lib/url_helper'
require './lib/constants'
require './lib/link/link_downloader'

class Link
  attr_accessor :source_file, :target, :type, :anchor,
                :response_status, :link_string, :link_text, :line_no, :reference_intact

  include Constants

  def initialize(source_url, link_element, domain)
    @source_file = source_url
    @domain = domain

    if link_element
      @link_string = link_element['href']
      self.target = @link_string
      link_text = link_element.text
      @line_no = link_element.line
      determine_type
      extract_anchor
    else
      # If no link_element is provided, assume the source is the target and type is local.
      @link_string = source_url
      self.target = source_url
      @type = 'local'
    end
  end

  def target=(value)
    @target = value
    make_absolute
  end

  def link_text=(value)
    @link_text = value.strip.gsub(/\s+/, ' ')
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
    retries = 0

    target = loop do
      target = LINKS_MUTEX.synchronize do
        @target
      end
      if URI.parse(target).host
        target
      else
        raise StandardError, "waiting for link to become absolute but it never did" if retries >= MAX_RETRIES

        sleep(SLEEP_DURATION)
        retries += 1
      end
    end

    LinkDownloader.new(target)
    downloader.fetch_content
  rescue Errno::ECONNREFUSED => e
    PRY_MUTEX.synchronize{binding.pry}
  end

  def check_reference_intact!(escaped, doc)
    @reference_intact = !doc.css("[name=#{escaped}], ##{escaped}, [id=#{escaped}]").empty?
  end

  def reference_intact?
    @reference_intact
  end

  def set_error(error_message)
    @error = error_message
  end

  def has_error?
    !@error.nil?
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
    @anchor = URLHelper.extract_fragment(@link_string)
  end

  def make_absolute
    return unless @link_string
    @target = URLHelper.make_absolute(@source_file, @link_string)
  end
end

require './lib/link/link_analyzer'
