require "rake"

module Rum
  class ArtifactTask < Rake::FileTask
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        stage_name, arg_names, deps = Rum.application.resolve_args(args)
        iidfile = Rum.application.current_manifest.iidfile(deps.first)
        super(stage_name, arg_names => iidfile)
      end
    end

    def enhance_run(&block)
      directory path unless path == "."
      enhance([path]) do |f,args|
        # Exec artifact block
        run.instance_exec(self, args, &block) if block_given?

        # Append defaults
        run.with_defaults(entrypoint: "cat", rm: true)

        # Export artifact
        sh run.to_s
      end
    end

    def digest
      @digest ||= File.read(prerequisite_tasks.first.name)
    end

    def manifest
      @manifest ||= Rum.application.current_manifest
    end

    def path
      File.dirname(name)
    end

    def run
      @run ||= Docker::Run.new(digest, "> #{name}", env: manifest.env)
    end
  end

  class BuildTask < Rake::Task
    def enhance_build(&block)
      # Initialize build
      build

      enhance do |t,args|

        # Exec stage block
        build.instance_exec(self, args, &block) if block_given?

        # Run build
        sh build.to_s
      end
    end
  end

  class ExportTask < Rake::FileTask
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        stage_name, arg_names, deps = Rum.application.resolve_args(args)
        iidfile = Rum.application.current_manifest.iidfile(deps.first)
        super(stage_name, arg_names => iidfile)
      end
    end

    def enhance_run(&block)
      directory path unless path == "."
      enhance([path]) do |f,args|
        # Exec artifact block
        run.instance_exec(self, args, &block) if block_given?

        # Append defaults
        run.with_defaults(entrypoint: "cat", rm: true)

        # Export artifact
        sh run.to_s
      end
    end

    def digest
      @digest ||= File.read(prerequisite_tasks.first.name)
    end

    def manifest
      @manifest ||= Rum.application.current_manifest
    end

    def path
      File.dirname(name)
    end

    def run
      @run ||= Docker::Run.new(digest, "> #{name}", env: manifest.env)
    end
  end

  class RunTask < Rake::Task
    def enhance_run(&block)
      enhance do |f,args|
        # Exec artifact block
        run.instance_exec(self, args, &block) if block_given?

        # Append defaults
        run.with_defaults(entrypoint: "cat", rm: true)

        # Export artifact
        sh run.to_s
      end
    end
  end

  class IidfileTask < Rake::FileTask

  end

  class StageTask < Rake::Task
    include Rake::DSL

    class << self
      def define_task(*args, &block)
        stage_name, arg_names, deps = Rum.application.resolve_args(args)
        Rum.application.last_description = "Build `#{stage_name}` stage"
        super(stage_name, arg_names => deps)
      end
    end

    def enhance_build(&block)
      # Initialize build & run
      build
      run

      iiddeps = prereqs.empty? ? iidpath : prerequisite_stages.map(&:iidfile)

      # Define iidfile task
      directory iidpath
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
        sh build.to_s.gsub(/ -/, " \\\n-")
        cp tsfile, iidfile
      end

      # Define clean task
      clean_name = task_name(clean: name)
      desc "Remove temporary products through `#{name}` stage"
      task(clean_name) { rm iidfile if File.exist?(iidfile) }

      # Define clobber task
      clobber_name = task_name(clobber: name)
      desc "Remove any images and temporary products through `#{name}` stage"
      task(clobber_name) do
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

      # Define shell task
      shell_name = task_name(shell: name)
      desc "Shell into `#{name}` stage"
      task(shell_name, [:shell] => name) do |t,args|
        run.with_defaults(
          entrypoint:  args[:shell] || "/bin/sh",
          interactive: true,
          rm:          true,
          tty:         true,
        )
        sh run.to_s.gsub(/ -/, " \\\n-")
      end

      # Add clean/clobber tasks
      task :clean => clean_name
      task :clobber => clobber_name

      # Ensure clobber order is reverse of stage dependencies
      prereqs.each{|stage| task task_name(clobber: stage) => clobber_name }

      # Add iidfile as dependent task
      enhance([iidfile])
    end

    def build
      @build ||= Docker::Build.new(manifest.path, build_arg: manifest.env)
    end

    def digest
      @digest ||= File.read(iidfile) if File.exist?(iidfile)
    end

    def iidfile
      manifest.iidfile(name)
    end

    def iidpath
      File.dirname(iidfile)
    end

    def manifest
      @manifest ||= Rum.application.current_manifest
    end

    def prerequisite_stages
      prerequisite_tasks.select{|x| x.is_a? StageTask }
    end

    def run(cmd = nil)
      @run ||= Docker::Run.new(digest, cmd, env: manifest.env)
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

    def tsfile
      @tsfile ||= "#{iidfile}@#{Time.now.to_i}"
    end
  end
end
