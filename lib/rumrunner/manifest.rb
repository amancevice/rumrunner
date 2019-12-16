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
    attr_reader :image, :home, :path

    def_delegator :@env, :<<, :env
    def_delegators :@image, :registry, :username, :name, :tag, :to_s

    ##
    # Initialize new manifest with name, build path, and home path for caching
    # build digests. Evaluates <tt>&block</tt> if given.
    #
    # Example:
    #   Manifest.new(name: "my_image", path: ".", home: ".docker")
    #
    def initialize(name:, path:nil, home:nil, env:nil)
      @image = Docker::Image.parse(name)
      @home  = home || ENV["RUM_HOME"] || ".docker"
      @path  = path || ENV["RUM_PATH"] || "."
      @env   = env  || []
    end

    def iidpath
      File.join(@home, @image.family)
    end

    def iidfile(stage)
      File.join(iidpath, "#{@image.tag}-#{stage}")
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
      task(*args) do |t,args|
        build = Docker::Build.new(options: build_options, path: @path)
        build.instance_exec(t, args, &block) if block_given?
        sh build.to_s
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
      task(*args) do |t,args|
        run = Docker::Run.new(options: run_options, image: @image)
        run.instance_exec(t, args, &block) if block_given?
        sh run.to_s
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
      stage_name, arg_names, deps = application.resolve_args(args)

      # Define stage task
      stage_task(stage_name, arg_names, deps)

      # Define iidfile task
      stage_file(stage_name, arg_names, &block)

      # Define shell:stage task
      stage_shell(stage_name)

      # Define clean:stage task
      stage_clean(stage_name, deps)
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
        Dir[File.join(@home, "**/*")].reverse.each do |name|
          sh "docker", "image", "rm", "--force", File.read(name) if File.file?(name)
          rm_rf name
        end
        rm_rf @home if Dir.exist?(@home)
      end
    end

    ##
    # Install :default task that builds the image
    def install_default
      iidfile = File.join(@home, *image)
      file iidfile do |t|
        tsfile = "#{t.name}@#{Time.now.utc.to_i}"
        build  = Docker::Build.new(options: build_options, path: @path)
        build.with_defaults(iidfile: tsfile, tag: tag || :latest)
        sh build.to_s
        cp tsfile, iidfile
      end
      task :default => iidfile
    end

    ##
    # Install alias task for building stage
    def stage_task(stage_name, arg_names, deps)
      desc "Build `#{stage_name}` stage"
      task stage_name, arg_names => deps + [iidfile(stage_name)]
    end

    ##
    # Install file task for stage and save digest in iidfile
    def stage_file(stage_name, arg_names, &block)
      file iidfile(stage_name) => iidpath do |f,args|
        tsfile = "#{f.name}@#{Time.now.utc.to_i}"
        build = Docker::Build.new(options: build_options, path: @path)
        build.instance_exec(Rake::Task[stage_name], args, &block) if block_given?
        build.with_defaults(
          iidfile: tsfile,
          tag:     "#{@image}-#{stage_name}",
          target:  stage_name,
        )
        sh build.to_s
        cp tsfile, f.name
      end
    end

    ##
    # Install shell task for shelling into stage
    def stage_shell(stage_name)
      desc "Shell into `#{stage_name}` stage"
      task task_name(shell: stage_name), [:shell] => stage_name do |t,args|
        digest = File.read(iidfile(stage_name))
        shell = args.any? ? args.to_a.join(" ") : "/bin/sh"
        run = Docker::Run.new(options: run_options, image: digest)
        run.with_defaults(
          entrypoint:  shell,
          interactive: true,
          rm:          true,
          tty:         true,
        )
        sh run.to_s
      end
    end

    ##
    # Install clean tasks for cleaning up stage image and iidfile
    def stage_clean(stage_name, deps)
      clean_name = task_name(clean: stage_name)
      desc "Remove any images and temporary products through `#{stage_name}` stage"
      task clean_name do
        file_name = iidfile(stage_name)
        if File.exist?(file_name)
          sh "docker", "image", "rm", "--force", File.read(file_name)
          rm_rf file_name
        end
      end

      # Add stage to general clean
      task :clean => clean_name

      # Ensure subsequent stages are cleaned before this one
      deps.each{|dep| task task_name(clean: dep) => clean_name }
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
