require "rake"

require "rumrunner/docker"

module Rum
  class ContextLayer < OpenStruct
  end

  class Context < Rake::LinkedList
    def initialize(head, tail=EMPTY)
      head = ContextLayer.new(**head)
      super
    end

    def build
      opts = {
        build_arg: env,
        iidfile: [iidfile],
        tag: [tag],
        target: [target].compact
      }
      args = [path]
      [opts, args]
    end

    def run(cmd=nil)
      opts = {
        env: env,
      }
      args = [cmd]
      [opts, args]
    end

    def digest
      File.read(iidfile)
    end

    def env(*args)
      if args.any?
        @head.env ||= []
        @head.env.concat(args)
      end
      map(&:env).compact.flatten
    end

    def iidpath
      @head.iidpath || @tail.iidpath
    end

    def iidfile
      File.join(iidpath, name, @head.tag)
    end

    def name
      @head.name || @tail.name
    end

    def path
      @head.path || @tail.path
    end

    def tag
      "#{name}:#{@head.tag || @tail.tag}"
    end

    def target
      @head.target || @tail.target
    end

    class DefaultContext < Rake::LinkedList::EmptyLinkedList
      @parent = Context
    end

    EMPTY = DefaultContext.new
  end
end
