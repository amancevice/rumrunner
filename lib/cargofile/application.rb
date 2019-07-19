require "rake"

module Cargofile
  class Application < Rake::Application

    # Initialize a Cargofile::Application object.
    def initialize
      super
      @rakefiles = [
        "cargofile",
        "Cargofile",
        "cargofile.rb",
        "Cargofile.rb",
      ]
    end

    # Initialize the command line parameters and app name.
    def init(app_name="cargo", argv = ARGV)
      super "cargo", ARGV
    end
  end
end
