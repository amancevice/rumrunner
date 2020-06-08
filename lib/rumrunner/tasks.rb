require "rake/task"
require "rake/file_task"

module Rum
  module DockerCommand
    def method_missing(m, *args, &block)
      p [m, args]
    end
  end

  class BuildTask < Rake::Task
    include DockerCommand
  end

  class RunTask < Rake::Task
    include DockerCommand
  end

  class StageTask < BuildTask
  end

  class ExportTask < RunTask
  end
end
