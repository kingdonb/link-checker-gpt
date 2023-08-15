class BaseLinkValidator
  attr_reader :link, :parsed_docs_cache, :links_mutex

  def initialize(link, parsed_docs_cache = {}, links_mutex = Mutex.new)
    @link = link
    @parsed_docs_cache = parsed_docs_cache
    @links_mutex = links_mutex
  end

  def valid_anchor?
    anchor = @link.anchor
    return false unless anchor && !anchor.empty?

    problematic_chars = %w[{}()]
    problematic_chars.none? { |char| anchor.include?(char) }
  end

  def escaped_anchor
    anchor = URI.decode_www_form_component(@link.anchor.to_s)
    anchor.gsub(":", "\\:")
      .gsub(".", "\\.")
      .gsub("/", "\\/")
  end
end
