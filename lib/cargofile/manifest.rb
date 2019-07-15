module Cargofile
  class Manifest
    extend Forwardable
    include Rake::DSL if defined? Rake::DSL

    def_delegator :@env, :<<, :env
    def_delegator :@root, :to_s, :root
    def_delegators :@image, :registry, :username, :name, :tag

    def initialize(name:, root:nil, &block)
      @name  = name
      @root  = root || :".docker"
      @image = Docker::Image.parse(name)
      @env   = []
      instance_eval(&block) if block_given?
    end

    def build(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      task name => deps do
        sh Docker::Build.new(&block).to_s
      end
    end

    def run(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      task name => deps do
        sh Docker::Run.new(&block).to_s
      end
    end

    def stage(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)

      # Assemble image/iidfile from manifest/stage name
      image   = "#{@image}-#{name}"
      iidfile = File.join(root, image)
      iidpath = File.split(iidfile).first

      # Ensure path to iidfile exists
      iiddeps = if deps.empty?
        directory iidpath
        iidpath
      else
        deps.map{|x| File.join(root, "#{@image}-#{x}") }
      end

      # Build stage and save digest in iidfile
      file iidfile => iiddeps do
        build = Docker::Build.new(options: build_options, &block)
        build.with_defaults(iidfile: iidfile, tag: image, target: name)
        sh build.to_s
      end

      # Shortcut to build stage by name
      desc "Build `#{name}` stage"
      task name => iidfile

      # Shell into stage
      desc "Shell into `#{name}` stage"
      task :"#{name}:shell" => iidfile do
        digest = File.read(iidfile)
        run = Docker::Run.new(options: run_options)
          .interactive(true)
          .rm(true)
          .tty(true)
          .image(digest)
          .cmd("/bin/bash")
        sh run.to_s
      end

      # Clean stage
      desc "Remove any temporary images and products from `#{name}` stage"
      task :"#{name}:clean" do
        if File.exists? iidfile
          sh "docker", "image", "rm", "--force", File.read(iidfile)
          rm iidfile
        end
      end

      # Add stage to general clean
      task :clean => :"#{name}:clean"

      # Ensure subsequent stages are cleaned before this one
      deps.each{|dep| task :"#{dep}:clean" => :"#{name}:clean" }
    end

    def artifact(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)

      target  = deps.first
      image   = "#{@image}-#{target}"
      iidfile = File.join(root, image)
      path    = File.split(name).first
      deps    = [iidfile]

      unless path == "."
        directory path
        deps << path
      end

      desc "Build `#{name}`"
      file name => deps do
        digest = File.read(iidfile)
        run = Docker::Run.new(options: run_options, image: digest, cmd: ["cat", name], &block)
        run.with_defaults(rm: true)
        sh "#{run} > #{name}"
      end

      task :clean do
        rm name if File.exists?(name)
        rm_r path if Dir.exists?(path) && path != "."
      end
    end

    def shell(*args, &block)
      target  = Rake.application.resolve_args(args).first
      name    = :"#{target}:shell"
      image   = "#{@image}-#{target}"
      iidfile = File.join(root, image)

      Rake::Task[name].clear if Rake::Task.task_defined?(name)

      desc "Shell into `#{name}` stage"
      task name => iidfile do
        digest = File.read(iidfile)
        run = Docker::Run.new(options: run_options, image: digest, &block)
        run.with_defaults(interactive:true, rm: true, tty: true)
        sh run.to_s
      end
    end

    def install
      install_clean
    end

    private

    def build_options
      Docker::Options.new(build_arg: @env)
    end

    def run_options
      Docker::Options.new(env: @env)
    end

    def install_clean
      desc "Remove any temporary images and products"
      task :clean do
        Dir[File.join root, "**/*"].reverse.each do |name|
          sh "docker", "image", "rm", "--force", File.read(name) if File.file?(name)
          rm_r name
        end
        rm_r root if Dir.exists?(root)
      end
    end
  end
end
