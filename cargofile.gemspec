
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cargofile/version"

Gem::Specification.new do |spec|
  spec.name          = "cargofile"
  spec.version       = Cargofile::VERSION
  spec.authors       = ["Alexander Mancevice"]
  spec.email         = ["smallweirdnum@gmail.com"]
  spec.summary       = %q{Experiment in building projects with multi-stage Dockerfiles}
  spec.description   = %q{Experiment in building projects with multi-stage Dockerfiles}
  spec.homepage      = "https://github.com/amancevice/cargofile.git"
  spec.license       = "MIT"
  spec.require_paths = ["lib"]
  spec.files         = Dir["README*", "LICENSE*", "lib/**/*"]
  spec.executables   = ["cargo"]

  spec.add_runtime_dependency "rake", "~> 12.3"

  spec.add_development_dependency "bundler",   "~> 2.0"
  spec.add_development_dependency "codecov",   "~> 0.1"
  spec.add_development_dependency "gems",      "~> 1.1"
  spec.add_development_dependency "pry",       "~> 0.12"
  spec.add_development_dependency "rspec",     "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.16"
end
