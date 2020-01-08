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
    def_delegators :@image, :registry, :username, :name, :tag

    class << self
      def install_tasks(image, **options, &block)
        new(image, **options).install(&block)
      end
    end

    ##
    # Initialize new manifest with name, build path, and home path for caching
    # build digests. Evaluates <tt>&block</tt> if given.
    #
    # Example:
    #   Manifest.new("my_image", path: ".", home: ".docker")
    #
    def initialize(name, path:nil, home:nil, env:nil)
      @image = Docker::Image.parse(name)
      @home  = home || ENV["RUM_HOME"] || ".docker"
      @path  = path || ENV["RUM_PATH"] || "."
      @env   = env  || []
    end

    ##
    # Get iidpath for storing iidfiles
    def iidpath
      File.join(@home, @image.family)
    end

    ##
    # Get iidfile path for given stage
    def iidfile(stage)
      File.join(iidpath, "#{@image.tag}-#{stage}")
    end

    ##
    # Manifest display name
    def inspect # :nodoc:
      handle = @image.tag.nil? || @image.tag.to_sym == :latest ? @image.family : @image.to_s
      "#<#{self.class}[#{handle}]>"
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
        build = Docker::Build.new(@path, **build_options)
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
        run = Docker::Run.new(@image, **run_options)
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
      shell(stage_name, [:shell]) do |t,args|
        entrypoint args[:shell] || "/bin/sh"
      end

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
      stage_name, arg_names, deps = application.resolve_args(args)
      shell_name = task_name(shell: stage_name)

      Rake::Task[shell_name].clear if Rake::Task.task_defined?(shell_name)

      desc "Shell into `#{stage_name}` stage"
      task shell_name, arg_names => deps + [stage_name] do |t,args|
        digest = File.read(iidfile(stage_name))
        run = Docker::Run.new(digest, **run_options)
        run.instance_exec(t, args, &block) if block_given?
        run.with_defaults(
          entrypoint:  "/bin/sh",
          interactive: true,
          rm:          true,
          tty:         true,
        )
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
      {build_arg: @env}
    end

    ##
    # Get the shared run options for the Manifest.
    def run_options
      {env: @env}
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
        build = Docker::Build.new(@path, **build_options)
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
        build = Docker::Build.new(@path, **build_options)
        tag = "#{@image}-#{stage_name}"
        build.instance_exec(Rake::Task[stage_name], args, &block) if block_given?
        build.with_defaults(iidfile: tsfile, tag: tag, target: stage_name)
        sh build.to_s
        cp tsfile, f.name
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
      file name => deps do |f,args|
        digest = File.read(iidfile)
        run = Docker::Run.new(digest, [name], **run_options)
        run.instance_exec(f, args, &block) if block_given?
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
