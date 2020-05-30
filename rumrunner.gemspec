lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rumrunner/version"

Gem::Specification.new do |spec|
  spec.name          = "rumrunner"
  spec.version       = Rum::VERSION
  spec.authors       = ["Alexander Mancevice"]
  spec.email         = ["smallweirdnum@gmail.com"]
  spec.summary       = %q{Rum Runner is a Rake-based utility for building projects with multi-stage Dockerfiles}
  spec.description   = <<~DESCRIPTION
    Rum Runner is a Rake-based utility for building multi-stage Dockerfiles.

    Users can pair a multi-stage Dockerfile with a Rumfile that uses a
    Rake-like DSL to customize each stage's build options and dependencies.

    The `rum` executable allows users to easily invoke builds, shell-into
    specific stages for debugging, and export artifacts from built containers.

    Rum Runner has the following features:
    * Fully compatible with Rake
    * Rake-like DSL/CLI that enable simple annotation and execution of builds
    * Rumfiles are completely defined in standard Ruby syntax, like Rakefiles
    * Users can chain Docker build stages with prerequisites
    * Artifacts can be exported from stages
    * Shell tasks are automatically provided for every stage
    * Stage, artifact, and shell, steps can be customized
  DESCRIPTION
  spec.homepage      = "https://github.com/amancevice/rumrunner.git"
  spec.license       = "MIT"
  spec.require_paths = ["lib"]
  spec.files         = Dir["README*", "LICENSE*", "lib/**/*"]
  spec.executables   = ["rum"]

  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)

  spec.add_dependency "rake", "~> 13.0"
end
