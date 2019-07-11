module Cargofile
  module Buildable
    extend Forwardable
    include Rake::DSL

    attr_reader :name

    def_delegator :@build, :options
    def_delegator :options, :method_missing
    def_delegator :@root, :to_s, :root

    def initialize(root:, name:, image:nil, build:nil, &block)
      @root  = root
      @name  = name
      @image = image || Docker::Image.parse(name)
      @build = build || Docker::Build.new
      instance_eval(&block) if block_given?
    end

    def build(options = {}, &block)
      @build.options.update(options)
      block_given? ? yield(@build) : @build
    end

    def image(options = {}, &block)
      if options.empty?
        @image
      elsif options.is_a?(Hash)
        @image.update(options)
      else
        @image = Docker::Image.parse(options.to_s)
      end
      block_given? ? yield(@image) : @image
    end

    def path
      File.join root, @image.family
    end

    def iidfile
      File.join path, @image.tag
    end
  end

  module Runnable
    extend Forwardable
    include Rake::DSL

    def_delegators :@run, :options, :cmd
    def_delegator :options, :method_missing
    def_delegator :@name, :to_s, :name

    def initialize(name:, target:, &block)
      @name   = name
      @target = target
      @run    = Docker::Run.new
      instance_eval(&block) if block_given?
    end
  end

  class Manifest
    include Buildable

    attr_reader :artifacts, :targets

    def initialize(root:, name:, &block)
      @root  = root
      @name  = name
      @image = Docker::Image.parse(name)
      @build = Docker::Build.new
      instance_eval(&block) if block_given?
    end

    def artifact(*args, &block)
      target, name = args.first.first
      Artifact.new(name: name, target: target, &block).install
    end

    def shell(*args, &block)
      name_target  = args.first
      name, target = name_target.is_a?(Hash) ? name_target.first : [name_target, nil]
      Shell.new(name: name, target: target, &block).install
    end

    def target(*args, &block)
      name_target  = args.first
      name, target = name_target.is_a?(Hash) ? name_target.first : [name_target, nil]
      image = Docker::Image.parse("#{@image}-#{name}")
      build = @build.clone
      task name => target unless target.nil?
      Target.new(root: @root, name: name, image: image, build: build, &block).install
    end

    def install
      desc "Remove any temporary images and products"
      task :clean do
        Dir[File.join root, "*", "**"].each do |iidfile|
          sh "docker", "image", "rm", "--force", File.read(iidfile)
          File.delete iidfile
        end
        rm_rf root if Dir.exists?(root)
      end
    end
  end

  class Target
    include Buildable

    def install
      @iidfile = iidfile

      # Create path for iidfiles
      directory path

      # Build Docker image and save digest to `@path`
      file @iidfile => path do
        @build.options[:iidfile] ||= [@iidfile]
        @build.options[:tag]     ||= [@image.to_s]
        @build.options[:target]  ||= [@name]
        sh *@build
      end

      # Declare shortcut for building image
      desc "Build `#{@name}` stage"
      task @name => @iidfile

      # Helper to remove single stage
      desc "Remove any temporary images and products from `#{@name}` stage"
      task :"clean:#{@name}" do
        if File.exists? @iidfile
          sh "docker", "image", "rm", "--force", File.read(@iidfile)
          File.delete @iidfile
        end
      end
      task :clean => :"clean:#{@name}"

      self
    end
  end

  class Artifact
    include Runnable

    def install
      desc "Build #{name}"
      file name => @target do |f|
        iidfile = f.prerequisite_tasks.first.prereqs.first
        digest  = File.read(iidfile)
        @run.image digest
        @run.cmd   "cat", name unless @run.cmd
        sh "#{@run} > #{name}"
      end

      self
    end
  end

  class Shell
    include Runnable

    def install
      desc "Shell into container at `#{@name}` stage"
      task :"shell:#{@name}" => @name do |f|
        iidfile = f.prerequisite_tasks.first.prereqs.last
        digest  = File.read(iidfile)
        @run.options[:rm]          ||= [true]
        @run.options[:interactive] ||= [true]
        @run.options[:tty]         ||= [true]
        @run.image digest
        @run.cmd @target unless @run.cmd
        sh *@run
      end

      self
    end
  end
end
