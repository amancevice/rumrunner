require "rumrunner/docker"

module Rum
  class << self
    def init(input = nil, stdin = $stdin, stdout = $stdout, stderr = $stderr)
      # Get image name from stdin
      stderr.write "Docker image name [#{default = File.split(Dir.pwd).last}]: "
      input ||= stdin.gets.chomp
      image   = Docker::Image.parse(input.empty? ? default : input)

      # Begin Rumfile
      stdout.write "#!/usr/bin/env ruby\n"
      stdout.write "rum :\"#{image.family}\" do\n"

      # Put stages
      if File.exists? "Dockerfile"
        lines  = File.read("Dockerfile").scan(/^FROM .*?$/)
        stages = lines.each_with_index.map do |line, i|
          line.scan(/ AS (.*?)$/).flatten.first || i.to_s
        end
        stages.reverse.zip(stages.reverse[1..-1]).reverse.each do |stage, dep|
          if dep.nil?
            stdout.write "  stage :\"#{stage}\"\n"
          else
            stdout.write "  stage :\"#{stage}\" => :\"#{dep}\"\n"
          end
        end
      end

      # Fin
      stdout.write "end\n"
    end
  end
end
