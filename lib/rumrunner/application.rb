# frozen_string_literal: true
require "rake"

module Rum

  ##
  # Rum main application object. When invoking +rum+ from the
  # command line, a Rum::Application object is created and run.
  class Application < Rake::Application

    ##
    # Default names for Rum Runner manifests.
    DEFAULT_RAKEFILES = [
      "rumfile",
      "Rumfile",
      "rumfile.rb",
      "Rumfile.rb",
    ]

    ##
    # Initialize a Rumfile::Application object.
    def initialize
      super
      @name = "rum"
      @rakefiles = DEFAULT_RAKEFILES.dup
    end

    ##
    # Initialize the command line parameters and app name.
    def init(app_name="rum", argv = ARGV)
      super "rum", argv
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
