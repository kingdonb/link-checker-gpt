require './lib/validator/base_link_validator'

class RemoteLinkValidator < BaseLinkValidator
  MAX_RETRIES = 3

  def validate
    puts "Validating: #{link.target}"

    retries = 0

    begin
      response = Net::HTTP.get_response(URI(link.target))
      link.response_status = response.code
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      retries += 1
      retry if retries < MAX_RETRIES
      puts "Error after #{MAX_RETRIES} retries for link #{link.target}: #{e.message}"
      link.set_error "Timeout"
    rescue SocketError => e
      puts "Network error for link #{link.target}: #{e.message}"
      link.set_error "Network Error"
    rescue StandardError => e
      puts "Unexpected error for link #{link.target}: #{e.message}"
      link.set_error "Error (#{e.message})"
    end
  end
end
