require "rake"

require "rumrunner/docker"

module Rum
  module ContextLayer
    attr_accessor :context,
                  :dockerfile,
                  :env,
                  :iidroot,
                  :repo

    def env
      @env ||= []
    end

    def iidfile
      File.join(iidpath, @head)
    end

    def iidpath
      File.join(iidroot, repo)
    end

    def iidroot
      @iidroot || @tail.iidroot
    end

    def repo
      @repo || @tail.repo
    end
  end

  class Context < Rake::LinkedList
    include ContextLayer

    class DefaultContext < Rake::LinkedList::EmptyLinkedList
      include ContextLayer
      @parent = Context

      def iidroot
        @iidroot ||= ".docker"
      end

      def repo
        @repo ||= File.basename(Dir.pwd)
      end
    end

    EMPTY = DefaultContext.new
  end
end
