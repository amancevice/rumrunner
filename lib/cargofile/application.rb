require "rake"

module Cargofile
  class Application < Rake::Application
    DEFAULT_RAKEFILES = [
      "cargofile",
      "Cargofile",
      "cargofile.rb",
      "Cargofile.rb",
    ]

    # Initialize a Cargofile::Application object.
    def initialize
      super
      @name = "cargo"
      @rakefiles = DEFAULT_RAKEFILES.dup
    end

    # Initialize the command line parameters and app name.
    def init(app_name="cargo", argv = ARGV)
      super "cargo", argv
    end
  end
end
