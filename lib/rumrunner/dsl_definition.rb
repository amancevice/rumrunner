# frozen_string_literal: true
require "rake"

require "rumrunner/manifest"

module Rum

  ##
  # Defines the DSL methods for Rum Runner.
  module DSL
    include Rake::DSL

    private

    ##
    # Main context block. Analagous to Rake namespace.
    #
    # Example:
    #   repo :namespace, name: "user/img", tag: "1.2.3", iidpath: ".docker" do
    #     # ...
    #   end
    def repo(name = nil, **options, &block)
      name = name.to_s if name.kind_of?(Symbol)
      name = name.to_str if name.respond_to?(:to_str)
      if name.nil?
        Rum.application.in_context(options, &block)
      elsif name.kind_of?(String)
        Rum.application.in_namespace(name) do
          Rum.application.in_context(**options, &block)
        end
      else
        raise ArgumentError, "Expected a String or Symbol for a repo name"
      end
    end

    ##
    # Enhance current context ENV
    def env(*args)
      Rum.application.current_context.env.concat(args)
    end

    ##
    # Rum base task block.
    #
    # Example
    #   rum :amancevice/rumrunner do
    #     tag %x(git describe --tags --always)
    #     # ...
    #   end
    #
    def rum(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      path, home = deps
      Manifest.new(name: name, path: path, home: home).install(&block)
    end
  end
end

self.extend Rum::DSL
