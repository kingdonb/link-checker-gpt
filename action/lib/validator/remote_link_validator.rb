require './lib/validator/base_link_validator'

class RemoteLinkValidator < BaseLinkValidator
  MAX_RETRIES = 3

  def validate
    @logger.debug "Validating: #{link.target}"

    retries = 0

    begin
      response = Net::HTTP.get_response(URI(link.target))
      link.response_status = response.code
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      retries += 1
      retry if retries < MAX_RETRIES
      @logger.warn "Error after #{MAX_RETRIES} retries for link #{link.target}: #{e.message}"
      link.set_error "Timeout"
    rescue SocketError => e
      @logger.warn "Network error for link #{link.target}: #{e.message}"
      link.set_error "Network Error"
    rescue StandardError => e
      @logger.warn "Unexpected error for link #{link.target}: #{e.message}"
      link.set_error "Error (#{e.message})"
    end
  end
end
