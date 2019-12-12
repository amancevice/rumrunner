require "rumrunner/version"
require "rumrunner/docker"
require "rumrunner/manifest"
require "rumrunner/dsl_definition"
require "rumrunner/application"
require "rumrunner/init"

##
# Rum Runner namespace.
module Rum
  class << self
    # Current Rum Application
    def application
      @application ||= Rum::Application.new
    end
  end
end
