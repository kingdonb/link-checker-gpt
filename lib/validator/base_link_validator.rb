class BaseLinkValidator
  attr_reader :link, :parsed_docs_cache

  def initialize(link, parsed_docs_cache = {})
    @link = link
    @parsed_docs_cache = parsed_docs_cache
  end

  def valid_anchor?(anchor)
    return false unless anchor && !anchor.empty?

    problematic_chars = %w[{}()]
    problematic_chars.none? { |char| anchor.include?(char) }
  end

  def escaped_anchor(anchor)
    anchor.gsub(":", "\\:")
          .gsub(".", "\\.")
          .gsub("%", "\\%")
          .gsub("/", "\\/")
  end
end
