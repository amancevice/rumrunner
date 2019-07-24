require "rake"

require "rumrunner/manifest"

module Rum

  ##
  # Defines the DSL methods for Rum Runner.
  module DSL

    private

    ##
    # :call-seq:
    #   rum image_name
    #   rum :image_name => "digest_dir"
    #
    # Example
    #   rum :amancevice/rumrunner do
    #     tag %x(git describe --tags --always)
    #     # ...
    #   end
    #
    def rum(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      root = deps.first || :".docker"
      Manifest.new(name: name, root: root, &block).install
    end
  end
end

self.extend Rum::DSL
