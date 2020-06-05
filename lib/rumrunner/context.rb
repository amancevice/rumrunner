require "rake"

require "rumrunner/docker"

module Rum
  module ContextManager
    include Rake::TaskManager

    def initialize # :nodoc:
      super
      @context = ContextList.new(
        name: File.basename(Dir.pwd),
        iidpath: ".docker",
        path: ".",
      )
    end

    def current_context
      @context
    end
  end

  class Context < OpenStruct
    # attr_reader :env

    # def initialize(hash=nil, env=nil)
    #   @env = env || []
    #   super(hash)
    # end
  end

  class ContextList < Rake::LinkedList
    def initialize(head, tail=EMPTY)
      head = Context.new(head)
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

    class DefaultContextList < Rake::LinkedList::EmptyLinkedList
      @parent = ContextList

      def target
        nil
      end
    end

    EMPTY = DefaultContextList.new
  end
end
