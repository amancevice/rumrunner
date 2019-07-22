require "rumrunner/docker"

module Rum
  class << self
    def init
      # Get image name from stdin
      $stderr.write "Docker image name: "
      image = Docker::Image.parse(gets.chomp)

      puts "#!/usr/bin/env ruby"
      puts "rum :\"#{image.family}\" do"
      File.read("Dockerfile").scan(/^FROM .*?$/).each_with_index do |line, i|
        stage = line.scan(/ AS (.*?)$/).flatten.first || i.to_s
        puts "  stage :\"#{stage}\""
      end if File.exists? "Dockerfile"
      puts "end"
    end
  end
end
