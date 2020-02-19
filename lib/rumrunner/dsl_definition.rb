# frozen_string_literal: true
require "rake"

require "rumrunner/manifest"
require "rumrunner/tasks"

module Rum

  ##
  # Defines the DSL methods for Rum Runner.
  module DSL

    private

    ##
    # Rum base task block.
    #
    # Example
    #   rum :amancevice/rumrunner do
    #     tag %x(git describe --tags --always)
    #     # ...
    #   end
    #
    def rum(image, **options, &block)
      Rum.application.in_manifest(image, **options, &block)
    end

    def artifact(*args, &block)
      ArtifactTask.define_task(*args, &block)
    end

    def build(*args, &block)
      BuildTask.define_task(*args, &block)
    end

    def env(env_var)
      Rum.application.current_manifest.env << env_var
    end

    def export(*args, &block)
      ExportTask.define_task(*args, &block)
    end

    def run(*args, &block)
      RunTask.define_task(*args, &block)
    end

    def shell(*args, &block)
      ShellTask.define_task(*args, &block)
    end

    def stage(*args, &block)
      StageTask.define_task(*args, &block)
    end

    def tag(tag_name)
      Rum.application.current_manifest.image.tag(tag_name)
    end
  end
end

self.extend Rum::DSL
