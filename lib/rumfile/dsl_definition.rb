require "rake"

require "rumfile/manifest"

module Rumfile
  module DSL

    private

    # :call-seq:
    #   rum image_name
    #   rum image_name: digest_dir
    #
    def rum(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      root = deps.first || :".docker"
      Manifest.new(name: name, root: root, &block).install
    end
  end
end

self.extend Rumfile::DSL
