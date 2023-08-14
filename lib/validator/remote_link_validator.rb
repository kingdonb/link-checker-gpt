require './lib/validator/base_link_validator'

class RemoteLinkValidator < BaseLinkValidator
  MAX_RETRIES = 3

  def validate
    # return unless link[:link_target]

    puts "Validating: #{link[:link_target]}"

    retries = 0

    begin
      response = Net::HTTP.get_response(URI(link[:link_target]))
      link[:response_status] = response.code
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      retries += 1
      retry if retries < MAX_RETRIES
      puts "Error after #{MAX_RETRIES} retries for link #{link[:link_target]}: #{e.message}"
      link[:response_status] = "Timeout"
    rescue SocketError => e
      puts "Network error for link #{link[:link_target]}: #{e.message}"
      link[:response_status] = "Network Error"
    rescue StandardError => e
      puts "Unexpected error for link #{link[:link_target]}: #{e.message}"
      link[:response_status] = "Error"
    end
  end
end
