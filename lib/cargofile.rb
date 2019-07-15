require "forwardable"
require "securerandom"

require "rake"

require "cargofile/version"
require "cargofile/docker"
require "cargofile/manifest"

module Cargofile
  class Error < StandardError
  end
end

def cargo(*args, &block)
  name, _, deps = Rake.application.resolve_args(args)
  root = deps.first || :".docker"
  Cargofile::Manifest.new(name: name, root: root, &block).install
end
