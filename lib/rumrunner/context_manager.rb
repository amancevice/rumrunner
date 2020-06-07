require "rake/task_manager"

require "rumrunner/context"

module Rum
  module ContextManager
    include Rake::TaskManager

    def initialize # :nodoc:
      super
      @context = Context.make
    end

    def current_context
      @context
    end
  end
end
