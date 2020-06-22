# frozen_string_literal: true
require "rake"

require "rumrunner/version"
require "rumrunner/context_manager"
require "rumrunner/context"
require "rumrunner/init"

module Rum

  ##
  # Rum main application object. When invoking +rum+ from the
  # command line, a Rum::Application object is created and run.
  class Application < Rake::Application
    include ContextManager

    ##
    # Default names for Rum Runner manifests.
    DEFAULT_RAKEFILES = [
      "rumfile",
      "Rumfile",
      "rumfile.rb",
      "Rumfile.rb",
    ].freeze

    ##
    # Initialize a Rumfile::Application object.
    def initialize
      super
      @name = "rum"
      @rakefiles = DEFAULT_RAKEFILES.dup
    end

    ##
    # Open Docker context
    def in_context(name)
      # Copied from Rake::DSL#namespace
      name = name.to_s if name.kind_of?(Symbol)
      name = name.to_str if name.respond_to?(:to_str)
      unless name.kind_of?(String) || name.nil?
        raise ArgumentError, "Expected a String or Symbol for a context name"
      end

      # Open namespace
      in_namespace(name) do
        @context = Context.new(name, @context)
        yield(@context)
        @context
      end
    ensure
      @context = @context.tail
    end

    ##
    # Initialize the command line parameters and app name.
    def init(app_name="rum", argv = ARGV)
      super
    end

    ##
    # Return true if any of the default Rumfiles exist
    def rumfile?
      DEFAULT_RAKEFILES.map{|x| File.size? x }.any?
    end

    ##
    # Run application
    def run(argv = ARGV)
      if argv.first == "init" && !rumfile?
        Rum.init
      elsif ["-V", "--version"].include? argv.first
        puts "rum, version #{Rum::VERSION}"
      else
        super
      end
    end
  end
end
