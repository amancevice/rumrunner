module Cargofile
  class Base
    extend Forwardable
    include Rake::DSL

    attr_reader :root, :name, :build

    def_delegator :@build, :options
    def_delegator :options, :method_missing

    def initialize(root:, name:, build:nil, image:nil, &block)
      @root  = root.to_s
      @name  = name.to_s
      @build = build || Docker::Build.new
      @image = image || Docker::Image.parse(name.to_s)
      instance_eval(&block) if block_given?
    end

    def image(options = {}, &block)
      if options.empty?
        @image
      elsif options.is_a?(Hash)
        @image = Docker::Image.new @image.to_h.update(options)
      else
        @image = Docker::Image.parse options.to_s
      end
    end

    def path
      File.join @root, @image.family
    end

    def iidfile
      File.join path, @image.tag
    end
  end

  class Manifest < Base
    attr_reader :artifacts, :targets

    def artifact(options = {}, &block)
      artifacts << nil
    end

    def artifacts
      @artifacts ||= []
    end

    def install
      # Install targets
      stages = targets.map(&:install)

      # Set up stage depdencencies
      stages.zip([path] + stages[0..-2]).each do |a,b|
        task a => b
        task :"clean:#{b}" => :"clean:#{a}"
      end

      # Clean up everything under @root
      desc "Remove any temporary images and products"
      task :clean do
        Dir[File.join root, "*", "**"].each do |iidfile|
          sh "docker", "image", "rm", "--force", File.read(iidfile)
          File.delete iidfile
        end
        rm_rf @root if Dir.exists?(@root)
      end
    end

    def target(name, &block)
      image   = @image.clone.tag "#{@image.tag}-#{name}"
      iidfile = File.join @root, image.family, image.tag
      build   = @build.clone do |t|
        t.options[:iidfile] = [iidfile]
        t.options[:tag]     = [image.to_s]
        t.options[:target]  = [name]
      end
      targets << Target.new(root: @root, name: name, build: build, image: image, &block)
    end

    def targets
      @targets ||= []
    end
  end

  class Target < Base
    def install
      # Create path for iidfiles
      directory path

      # Build Docker image and save digest to `@path`
      file iidfile => path do
        sh *@build
      end

      # Declare shortcut for building image
      desc "Build through `#{@name}` stage"
      task @name => iidfile

      # Helper to remove single stage
      desc "Remove through `#{@name}` stage"
      task :"clean:#{@name}" do
        if File.exists? iidfile
          sh "docker", "image", "rm", "--force", File.read(iidfile)
          File.delete iidfile
        end
      end
      task :clean => :"clean:#{@name}"

      # Helper to shell into stage
      # desc "Shell into `#{@name}` stage"
      # task :"shell:#{@name}" => @name do
      #   sh *@shell
      # end

      @name
    end

    def shell(*args, &block)
      p self
      args    = ["/bin/bash"] if args.empty?
      image   = @image.to_s
      options = {
        rm:          [true],
        interactive: [true],
        tty:         [true],
      }
      @shell = Docker::Run.new(image: image, cmd: args, options: options, &block)
    end
  end
end
