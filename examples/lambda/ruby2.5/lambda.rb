require "json"

require "active_support/all"

def handler(event:, context:)
  puts "EVENT    #{event.to_json}"
  response = {time: Time.now.utc - 1.day}
  puts "RESPONSE #{response.to_json}"
end
