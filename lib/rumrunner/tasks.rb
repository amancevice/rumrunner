require "rake/task"
require "rake/file_task"

module Rum
  module DockerCommand
    def method_missing(m, *args, &block)
      p [m, args]
    end
  end

  class BuildTask < Rake::Task
    extend Rake::DSL
    attr_accessor :context
  end

  class RunTask < Rake::Task
  end

  class StageTask < BuildTask
    class << self
      def define_task(*args, &block)
        # Define empty stage task
        target, arg_names, deps, order_only = Rum.application.resolve_args(args)
        task = super(target)

        # Enter new context for this target
        Rum.application.in_context(target) do |context|
          task.context = context
          task.enhance([context.iidfile])

          # Define FileTask to build stage iidfile
          directory(context.iidpath)
          file = Rake::FileTask.define_task(context.iidfile, arg_names => context.iidpath, order_only: order_only)
          file.enhance(deps) do |f,args|
            yield(task, args) if block_given?
            puts "docker build --iidfile #{f.name}"
          end

          # Define stage:build task
          super(:build => file.name)

          # Define stage:run task
          super(:run, %i[cmd] => file.name) do |t,args|
            puts "docker run $(cat #{file.name}) #{args.cmd}"
          end
        end
      end
    end
  end

  class ExportTask < RunTask
  end
end
