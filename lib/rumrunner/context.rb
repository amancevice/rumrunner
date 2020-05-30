require "rake"

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

  class Context < Rake::LinkedList

    EMPTY = Context.new(OpenStruct.new(iidpath: ".iidpath", path: ".", tag: "latest"))

    def env
      @head.env ||= []
    end

    def iidpath
      @head.iidpath || @tail.iidpath
    end

    def iidfile
      File.join(iidpath, name, tag)
    end

    def name
      @head.name || @tail.name
    end

    def path
      @head.path || @tail.path
    end

    def tag
      @head.tag || @tail.tag
    end

    def target
      @head.target || @tail.target
    end
  end
end
