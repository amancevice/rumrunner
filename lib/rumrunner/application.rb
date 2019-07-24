# frozen_string_literal: true
require "rake"

module Rum

  ##
  # Rum main application object. When invoking +rum+ from the
  # command line, a Rum::Application object is created and run.
  class Application < Rake::Application

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
  end
end
