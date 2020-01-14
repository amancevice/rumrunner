require "rake"

module Rum
  class ExportTask < Rake::FileTask
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        stage_name, arg_names, deps = Rum.application.resolve_args(args)
        Rum.application.last_description ||= "Export `#{stage_name}` from `#{deps.first}` stage"
        super(stage_name, arg_names => deps)
      end
    end

    def install(&block)
      enhance do |f,args|
        # Exec artifact block
        run.instance_exec(self, args, &block) if block_given?

        # Append defaults
        run.with_defaults(entrypoint: "cat", rm: true)

        # Export artifact
        sh run.to_s
      end

      # Define directory path
      unless path == "."
        directory path
        enhance [path]
      end

      prereqs.prepend(iidfile).delete(stage_name)
    end

    def digest
      @digest ||= File.read(iidfile) if File.exist?(iidfile)
    end

    def iidfile
      @iidfile ||= manifest.iidfile(stage_name)
    end

    def manifest
      @manifest ||= Rum.application.current_manifest
    end

    def path
      @path ||= File.dirname(name)
    end

    def run
      @run ||= Docker::Run.new(digest, "> #{name}", env: manifest.env)
    end

    def stage
      Rake::Task[stage_name]
    end

    def stage_name
      @stage ||= prereqs.first
    end
  end

  class ArtifactTask < ExportTask
    def install(&block)
      super
      install_clobber
    end

    private

    def install_clobber
      task(:clobber) { rm name if File.exist?(name) }
    end
  end

  class BuildTask < Rake::Task
    include Rake::DSL

    def install(&block)
      manifest
      enhance do |t,args|
        # Exec stage block
        build.instance_exec(self, args, &block) if block_given?

        # Append defaults to build
        build.with_defaults(
          file: manifest.file,
          tag:  manifest.image,
        )

        # Run build
        sh build.to_s
      end
    end

    def build
      @build ||= Docker::Build.new(manifest.path, build_arg: manifest.env)
    end

    def manifest
      @manifest ||= Rum.application.current_manifest
    end
  end

  class RunTask < Rake::Task
    def install(&block)
    end
  end

  class StageTask < Rake::FileTask
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        stage_name, arg_names, deps = Rum.application.resolve_args(args)
        Rum.application.last_description ||= "Build `#{stage_name}` stage"
        super(stage_name, arg_names => deps)
      end
    end

    def install(&block)
      install_build(&block)
      install_clean
      install_clobber
      install_shell
    end

    def build
      @build ||= Docker::Build.new(manifest.path, build_arg: manifest.env)
    end

    def digest
      @digest ||= File.read(iidfile) if File.exist?(iidfile)
    end

    def iidfile
      @iidfile ||= manifest.iidfile(name)
    end

    def iidpath
      @iidpath ||= File.dirname(iidfile)
    end

    def manifest
      @manifest ||= Rum.application.current_manifest
    end

    def run(cmd = nil)
      @run ||= Docker::Run.new(digest, cmd, env: manifest.env)
    end

    def tsfile
      @tsfile ||= "#{iidfile}@#{Time.now.to_i}"
    end

    private

    def install_build(&block)
      directory iidpath

      iiddeps = prereqs.empty? ? iidpath : [] # prereqs.map{|x| manifest.iidfile(stage) }

      file iidfile, arg_names => iiddeps do |f,args|

        # Exec stage block
        build.instance_exec(self, args, &block) if block_given?

        # Append defaults to build
        build.with_defaults(
          file:    manifest.file,
          iidfile: tsfile,
          tag:     manifest.image(name),
          target:  name,
        )

        # Run build
        sh build.to_s

        # Copy working iidfile to target
        cp tsfile, iidfile
      end

      enhance [iidfile]
    end

    def install_clean
      clean_name = task_name(clean: name)
      desc "Remove temporary products through `#{name}` stage"
      task(clean_name) { rm iidfile if File.exist?(iidfile) }

      desc "Remove temporary products"
      task :clean => clean_name
    end

    def install_clobber
      clobber_name = task_name(clobber: name)
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
      prereqs.each{|stage| task task_name(clobber: stage) => clobber_name }
    end

    def install_shell
      desc "Shell into `#{name}` stage"
      task task_name(shell: name), [:shell] => name do |t,args|
        run.with_defaults(
          entrypoint:  args[:shell] || "/bin/sh",
          interactive: true,
          rm:          true,
          tty:         true,
        )
        sh run.to_s.gsub(/ -/, " \\\n-")
      end
    end

    ##
    # Get name of support task
    def task_name(**verb_stage)
      case ENV["RUM_TASK_NAMES"]&.upcase
        when "STAGE_FIRST" then verb_stage.first.reverse
        when "VERB_FIRST" then verb_stage.first
        else verb_stage.first
      end.join(":").to_sym
    end
  end

  class ShellTask < Rake::Task
  end
end
