require "forwardable"
require "securerandom"

require "cargofile/docker"
require "cargofile/manifest"
require "cargofile/version"

module Cargofile
  class Error < StandardError
  end
end

def cargo(*args, &block)
  name_root  = args.first
  name, root = name_root.is_a?(Hash) ? name_root.first : [name_root, nil]
  Cargofile::Manifest.new(name: name, root: root, &block).install
end
