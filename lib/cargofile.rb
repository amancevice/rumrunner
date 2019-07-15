require "forwardable"
require "securerandom"

require "rake"

require "cargofile/docker"
require "cargofile/manifest"
require "cargofile/version"

module Cargofile
  class Error < StandardError
  end
end

def cargo(*args, &block)
  name, _, deps = Rake.application.resolve_args(args)
  root = deps.first || :".docker"
  Cargofile::Manifest.new(name: name, root: root, &block).install
end
