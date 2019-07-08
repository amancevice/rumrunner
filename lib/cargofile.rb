require "forwardable"
require "securerandom"

require "rake/clean"

require "cargofile/docker"
require "cargofile/manifest"
require "cargofile/version"

require "pry"

module Cargofile
  class Error < StandardError
  end
end

def cargo(name, &block)
  name, dir = name.is_a?(Hash) ? name.first : [name.to_s, ".docker"]
  Cargofile::Manifest.new(name: name, dir: dir, &block).install
end
