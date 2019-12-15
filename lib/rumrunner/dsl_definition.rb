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
    def rum(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      path, home = deps
      Manifest.new(name: name, path: path, home: home).install(&block)
    end
  end
end

self.extend Rum::DSL
