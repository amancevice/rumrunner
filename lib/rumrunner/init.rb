require "rumrunner/docker"

module Rum
  class << self

    ##
    # Helper to initialize a +Rumfile+
    #
    # Example:
    #   $ ruby -r rumrunner -e Rum.init > Rumfile
    #
    def init(input = nil, stdin = $stdin, stdout = $stdout, stderr = $stderr)
      # Get image name from $stdin
      image = gets_image input, stdin, stderr

      # Begin Rumfile
      stdout.write "#!/usr/bin/env ruby\n"
      stdout.write "rum :\"#{image.family}\" do\n"
      stdout.write parse_stages "Dockerfile" if File.exist? "Dockerfile"
      stdout.write "end\n"
    end

    private

    ##
    # Get Docker image from input (taken from <tt>$stdin</tt> if nil)
    def gets_image(input = nil, stdin = $stdin, stderr = $stderr)
      if input.nil?
        default = File.split(Dir.pwd).last
        stderr.write "Docker image name [#{default}]: "
        input = stdin.gets.chomp
      end
      Docker::Image.parse(input.empty? ? default : input)
    end

    ##
    # Parse stages from Dockerfile
    def parse_stages(dockerfile)
      stages = File.read(dockerfile).scan(/^FROM .*? AS (.*?)$/).flatten
      deps   = [nil] + stages[0..-2]
      lines  = stages.zip(deps).map do |stage, dep|
        dep.nil? ? %{  stage :"#{stage}"\n} : %{  stage :"#{stage}" => :"#{dep}"\n}
      end.join
    end
  end
end
