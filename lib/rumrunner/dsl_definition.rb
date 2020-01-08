# frozen_string_literal: true
require "rake"

require "rumrunner/manifest"

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
      Manifest.install_tasks(image, **options, &block)
    end
  end
end

self.extend Rum::DSL
