require "forwardable"
require "rake"

module Rum

  ##
  # Rum Runner Manifest for managing Docker commands.
  class Manifest
    extend Forwardable
    include Rake::DSL if defined? Rake::DSL

    ##
    # Access Docker image object.
    attr_reader :image

    def_delegator :@env, :<<, :env
    def_delegator :@path, :to_s, :path
    def_delegator :@home, :to_s, :home
    def_delegators :@image, :registry, :username, :name, :tag, :to_s

    ##
    # Initialize new manifest with name, build path, and home path for caching
    # build digests. Evaluates <tt>&block</tt> if given.
    #
    # Example:
    #   Manifest.new(name: "my_image", path: ".", home: ".docker")
    #
    def initialize(name:, path:nil, home:nil, env:nil)
      @path  = path || ENV["RUM_PATH"] || "."
      @home  = home || ENV["RUM_HOME"] || ".docker"
      @env   = env  || []
      @image = Docker::Image.parse(name)
    end

    ##
    # Get application
    def application
      Rake.application
    end

    ##
    # Defines the default task for +rum+ executable.
    #
    # Example:
    #   default :task_or_file
    #   default :task_or_file => [:deps]
    #
    def default(*args, &block)
      name = Rake.application.resolve_args(args).first
      task :default => name
    end

    ##
    # Defines generic +docker build+ task.
    #
    # Example:
    #   build :name
    #   build :name => [:deps]
    #
    def build(*args, &block)
      task(*args) do
        sh Docker::Build.new(options: build_options, path: path, &block).to_s
      end
    end

    ##
    # Defines generic +docker run+ task.
    #
    # Example:
    #   run :name
    #   run :name => [:deps]
    #
    def run(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)

      images   = deps.map{|dep| Docker::Image.parse("#{@image}-#{dep}") }
      iidfiles = images.map{|image| File.join(home, *image) }

      task name => iidfiles do |t|
        image = t.prereqs.empty? ? to_s : File.read(t.prereqs.first)
        sh Docker::Run.new(options: run_options, image: image, &block).to_s
      end
    end

    ##
    # Defines +docker build+ task for the given stage.
    #
    # Example:
    #   stage :name
    #   stage :name => [:deps]
    #
    def stage(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)

      # Assemble image/iidfile from manifest/stage name
      image   = Docker::Image.parse("#{@image}-#{name}")
      iidfile = File.join(home, *image)
      iidpath = File.split(iidfile).first

      # Ensure path to iidfile exists
      iiddeps = if deps.empty?
        directory iidpath
        iidpath
      else
        images = deps.map{|x| Docker::Image.parse("#{@image}-#{x}") }
        images.map{|x| File.join(home, *x) }
      end

      # Build stage and save digest in iidfile
      stage_file(iidfile, iiddeps, tag: image, target: name, &block)

      # Shortcut to build stage by name
      stage_task(name, iidfile)

      # Shell into stage
      stage_shell(name, iidfile)

      # Clean stage
      stage_clean(name, iidfile, deps)
    end

    ##
    # Defines +docker run+ task for redirecting a file from a running
    # instance of the dependent stage's container to the local file
    # system.
    #
    # Example:
    #   artifact :name => [:stage]
    #
    def artifact(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)

      target  = deps.first
      image   = Docker::Image.parse("#{@image}-#{target}")
      iidfile = File.join(home, *image)
      path    = File.split(name).first
      deps    = [iidfile]

      unless path == "."
        directory path
        deps << path
      end

      artifact_file(name, deps, iidfile, &block)

      artifact_clobber(name, path)
    end

    ##
    # Defines +docker run+ task for shelling into the given stage.
    #
    # Example:
    #   shell :stage
    #   shell :stage => [:deps]
    #
    def shell(*args, &block)
      target  = Rake.application.resolve_args(args).first
      name    = task_name shell: target
      image   = Docker::Image.parse("#{@image}-#{target}")
      iidfile = File.join(home, *image)

      Rake::Task[name].clear if Rake::Task.task_defined?(name)

      desc "Shell into `#{target}` stage"
      task name, [:shell] => iidfile do |t,args|
        digest = File.read(iidfile)
        shell  = args.any? ? args.to_a.join(" ") : "/bin/sh"
        run    = Docker::Run.new(options: run_options, image: digest, &block)
        run.with_defaults(entrypoint: shell, interactive:true, rm: true, tty: true)
        sh run.to_s
      end
    end

    ##
    # Install any remaining tasks for the manifest.
    def install(&block)
      iidpath = File.join(@home, @image.family)
      directory(iidpath)
      instance_eval(&block) if block_given?
      install_default unless Rake::Task.task_defined?(:default)
      install_clean

      self
    end

    private

    ##
    # Get the shared build options for the Manifest.
    def build_options
      Docker::Options.new(build_arg: @env) unless @env.empty?
    end

    ##
    # Get the shared run options for the Manifest.
    def run_options
      Docker::Options.new(env: @env) unless @env.empty?
    end

    ##
    # Install :clean task for removing temporary Docker images and
    # iidfiles.
    def install_clean
      desc "Remove ALL images and temporary products"
      task :clean do
        Dir[File.join(home, "**/*")].reverse.each do |name|
          sh "docker", "image", "rm", "--force", File.read(name) if File.file?(name)
          rm_rf name
        end
        rm_rf home if Dir.exist?(home)
      end
    end

    ##
    # Install :default task that builds the image
    def install_default
      iidfile = File.join(home, *image)
      file iidfile do |t|
        tsfile = "#{t.name}@#{Time.now.utc.to_i}"
        build  = Docker::Build.new(options: build_options, path: path)
        build.with_defaults(iidfile: tsfile, tag: tag || :latest)
        sh build.to_s
        cp tsfile, iidfile
      end
      task :default => iidfile
    end

    ##
    # Install file task for stage and save digest in iidfile
    def stage_file(iidfile, iiddeps, tag:, target:, &block)
      file iidfile => iiddeps do |t|
        tsfile = "#{t.name}@#{Time.now.utc.to_i}"
        build  = Docker::Build.new(options: build_options, path: path, &block)
        build.with_defaults(iidfile: tsfile, tag: tag, target: target)
        sh build.to_s
        cp tsfile, iidfile
      end
    end

    ##
    # Install alias task for building stage
    def stage_task(name, iidfile)
      desc "Build `#{name}` stage"
      task name => iidfile
    end

    ##
    # Install shell task for shelling into stage
    def stage_shell(name, iidfile)
      desc "Shell into `#{name}` stage"
      task task_name(shell: name), [:shell] => iidfile do |t,args|
        digest = File.read(t.prereqs.first)
        shell  = args.any? ? args.to_a.join(" ") : "/bin/sh"
        run    = Docker::Run.new(options: run_options)
          .entrypoint(shell)
          .interactive(true)
          .rm(true)
          .tty(true)
          .image(digest)
        sh run.to_s
      end
    end

    ##
    # Install clean tasks for cleaning up stage image and iidfile
    def stage_clean(name, iidfile, deps)
      # Clean stage image
      desc "Remove any images and temporary products through `#{name}` stage"
      task task_name(clean: name) do
        if File.exist?(iidfile)
          sh "docker", "image", "rm", "--force", File.read(iidfile)
          rm_rf iidfile
        end
      end

      # Add stage to general clean
      task :clean => task_name(clean: name)

      # Ensure subsequent stages are cleaned before this one
      deps.each{|dep| task task_name(clean: dep) => task_name(clean: name) }
    end

    ##
    # Install file task for artifact
    def artifact_file(name, deps, iidfile, &block)
      desc "Build `#{name}`"
      file name => deps do
        digest = File.read(iidfile)
        run = Docker::Run.new(options: run_options, image: digest, cmd: [name], &block)
        run.with_defaults(rm: true, entrypoint: "cat")
        sh "#{run} > #{name}"
      end
    end

    ##
    # Install clobber tasks for cleaning up generated files
    def artifact_clobber(name, path)
      desc "Remove any generated files"
      task :clobber => :clean do
        rm_rf name
        rm_rf path unless path == "."
      end
    end

    ##
    # Get name of support task
    def task_name(verb_stage)
      case ENV["RUM_TASK_NAMES"]&.upcase
        when "STAGE_FIRST" then verb_stage.first.reverse
        when "VERB_FIRST" then verb_stage.first
        else verb_stage.first
      end.join(":").to_sym
    end
  end
end
