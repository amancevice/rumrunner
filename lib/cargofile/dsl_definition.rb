require "rake"

require "cargofile/manifest"

module Cargofile
  module DSL

    private

    # :call-seq:
    #   cargo image_name
    #   cargo image_name: digest_dir
    #
    def cargo(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      root = deps.first || :".docker"
      Manifest.new(name: name, root: root, &block).install
    end
  end
end

self.extend Cargofile::DSL
