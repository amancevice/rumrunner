lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rumfile/version"

Gem::Specification.new do |spec|
  spec.name          = "rumfile"
  spec.version       = Rumfile::VERSION
  spec.authors       = ["Alexander Mancevice"]
  spec.email         = ["smallweirdnum@gmail.com"]
  spec.summary       = %q{Rumfile is a Rake-based utility for building projects using multi-stage Dockerfiles}
  spec.description   = <<~DESCRIPTION
    Rumfile is a Rake-based utility for building projects using multi-stage Dockerfiles.

    Rumfile allows users to minimally annotate builds using a Rake-like DSL
    and execute them with a rake-like CLI.

    Carfofile has the following features:
    * Rumfiles are completely defined in standard Ruby syntax, like Rakefiles.
    * Users can specify Docker build stages with prerequisites.
    * Artifacts can be exported from stages
    * Stages' build steps can be customized
    * Shell tasks are automatically provided for every stage
  DESCRIPTION
  spec.homepage      = "https://github.com/amancevice/rumfile.git"
  spec.license       = "MIT"
  spec.require_paths = ["lib"]
  spec.files         = Dir["README*", "LICENSE*", "lib/**/*"]
  spec.executables   = ["rum"]

  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)

  spec.add_runtime_dependency "rake", "~> 12.3"

  spec.add_development_dependency "bundler",   "~> 2.0"
  spec.add_development_dependency "codecov",   "~> 0.1"
  spec.add_development_dependency "gems",      "~> 1.1"
  spec.add_development_dependency "pry",       "~> 0.12"
  spec.add_development_dependency "rspec",     "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.16"
end
