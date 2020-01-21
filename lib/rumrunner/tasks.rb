require "rake"

module Rum
  class Task < Rake::Task
    attr_reader :manifest

    class << self
      ##
      # Get name of sub-task
      def subtask_name(**verb_stage)
        case ENV["RUM_TASK_NAMES"]&.upcase
          when "STAGE_FIRST" then verb_stage.first.reverse
          when "VERB_FIRST" then verb_stage.first
          else verb_stage.first
        end.join(":").to_sym
      end
    end

    def initialize(task_name, app)
      super
      @manifest = app.current_manifest
    end

    def build
      @build ||= Docker::Build.new(manifest.path, build_arg: manifest.env)
    end

    def digest
      @digest ||= File.read(iidfile)
    end

    def iidfile
      @iidfile ||= manifest.iidfile(stage_name)
    end

    def iidpath
      @iidpath ||= File.dirname(iidfile)
    end

    def run(cmd = nil)
      @run ||= Docker::Run.new(digest, cmd, env: manifest.env)
    end

    def stage
      @stage ||= Rake::Task[stage_name]
    end

    def stage_name
      @stage_name ||= name
    end

    private

    def default_build_options
      @build_options ||= {file: manifest.file, tag: manifest.image}
    end

    def default_run_options
      @run_options ||= {}
    end

    def subtask_name(**verb_stage)
      self.class.subtask_name(**verb_stage)
    end
  end

  class BuildTask < Task
    def install(&block)
    end

    private

    def install_build(&block)
      enhance do |*args|
        build.instance_exec(*args, &block) if block_given?
        build.with_defaults(**default_build_options)
        sh build.to_s
      end
    end
  end

  class RunTask < Task

    def install(&block)
      install_run(&block)
    end

    private

    def install_run(&block)
      enhance do |*args|
        run.instance_exec(*args, &block) if block_given?
        run.with_defaults(**default_run_options)
        sh run.to_s
      end
    end

    def stage_name
      @stage_name ||= prereqs.first
    end
  end

  class ExportTask < RunTask
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        task_name, arg_names, deps = Rum.application.resolve_args(args)
        Rum.application.last_description ||= "Export `#{task_name}` from `#{deps.first}` stage"
        super(task_name, arg_names => deps){}.install(&block)
      end
    end

    def install(&block)
      install_run(&block)

      unless path =~ %r{\./?}
        directory path
        enhance [path]
      end

      prereqs.prepend(iidfile).delete(stage_name)

      self
    end

    def path
      @path ||= File.dirname(name) << "/"
    end

    def run(cmd = nil)
      super(cmd || "#{name} > #{name}")
    end

    private

    def default_run_options
      super.update(entrypoint: "cat", rm: true)
    end
  end

  class ArtifactTask < ExportTask
    def install(&block)
      super(&block)
      install_clobber
      self
    end

    private

    def install_clobber
      task(:clobber) { rm name if File.exist?(name) }
    end
  end

  class ShellTask < RunTask
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        stage_name, arg_names, deps = Rum.application.resolve_args(args)
        task_name = subtask_name(shell: stage_name)
        super(task_name, arg_names => deps){}.install(&block)
      end
    end

    def install(&block)
      install_run(&block)
      self
    end

    private

    def default_run_options
      super.update(
        entrypoint:  "/bin/sh",
        interactive: true,
        rm:          true,
        tty:         true,
      )
    end

    def install_run(&block)
      enhance do |*args|
        run.instance_exec(*args, &block) if block_given?
        run.with_defaults(**default_run_options)
        sh run.to_s
      end
    end
  end

  class StageTask < Task
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        task_name, arg_names, deps = Rum.application.resolve_args(args)
        Rum.application.last_description ||= "Build `#{task_name}` stage"
        stage_task = super(task_name, arg_names => deps) {}
        stage_task.install(&block)

        stage_task
      end
    end

    def install(&block)
      install_build(&block)
      install_clean
      install_clobber
      enhance [iidfile]
      self
    end

    def install_default_shell
      install_shell unless Rake::Task.task_defined? subtask_name(shell: name)
    end

    private

    def default_build_options
      super.update(iidfile: tsfile, target: name)
    end

    def default_run_options
      super.update(interactive: true, rm: true, tty: true)
    end

    def install_build(&block)
      directory iidpath

      iiddeps = prereqs.empty? ? iidpath : prereqs.map{|x| manifest.iidfile(x) }

      file iidfile, arg_names => iiddeps do |f,args|

        # Exec stage block
        build.instance_exec(self, args, &block) if block_given?

        # Append defaults to build
        build.with_defaults(**default_build_options)

        # Run build
        sh build.to_s

        # Copy working iidfile to target
        cp tsfile, iidfile
      end
    end

    def install_clean
      clean_name = subtask_name(clean: name)
      desc "Remove temporary products through `#{name}` stage"
      task(clean_name) { rm iidfile if File.exist?(iidfile) }

      desc "Remove temporary products"
      task :clean => clean_name
    end

    def install_clobber
      clobber_name = subtask_name(clobber: name)
      desc "Remove temporary products and images through `#{name}` stage"
      task clobber_name do
        FileList["#{iidfile}*"].reverse.inject({}) do |hash,x|
          sha256 = File.read(x)
          hash[sha256] ||= []
          hash[sha256]  << x

          hash
        end.each do |sha256,iidfiles|
          sh "docker image rm --force #{sha256}"
          iidfiles.each do |f|
            rm f
          end
        end
      end

      desc "Remove temporary products and images"
      task :clobber => clobber_name

      # Ensure clobber order is reverse of stage dependencies
      prereqs.each{|stage| task subtask_name(clobber: stage) => clobber_name }
    end

    def install_shell
      desc "Shell into `#{name}` stage"
      ShellTask.define_task name, [:sh] => name do |t,args|
        entrypoint args[:shell] || "/bin/sh"
      end
    end

    def tsfile
      @tsfile ||= "#{iidfile}@#{Time.now.to_i}"
    end
  end
end
