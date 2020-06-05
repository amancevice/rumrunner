# frozen_string_literal: true
require "rake"

require "rumrunner/manifest"

module Rum

  ##
  # Defines the DSL methods for Rum Runner.
  module DSL
    include Rake::DSL

    private

    ##
    # Main context block. Analagous to Rake namespace.
    #
    # Example:
    #   repo :namespace, name: "user/img", tag: "1.2.3", iidpath: ".docker" do
    #     # ...
    #   end
    def repo(name = nil, **options, &block)
      name = name.to_s if name.kind_of?(Symbol)
      name = name.to_str if name.respond_to?(:to_str)
      if name.nil?
        Rum.application.in_context(**options, &block)
      elsif name.kind_of?(String)
        Rum.application.in_namespace(name) do
          Rum.application.in_context(**options, &block)
        end
      else
        raise ArgumentError, "Expected a String or Symbol for a repo name"
      end
    end

    ##
    # Enhance current context ENV
    def env(*args)
      args.each do |arg|
        Rum.application.current_context.env << arg
      end
    end

    ##
    # Docker stage
    def stage(*args)
      app = Rum.application
      target, task_args, deps, * = app.resolve_args(args)

      app.in_context(target: target.to_s, tag: target.to_s) do |context|

        namespace :build do
          iidpath = File.dirname(context.iidfile)
          directory iidpath
          file context.iidfile, task_args => deps, order_only: iidpath do |f,args|
            puts "docker build #{f.name}"
          end
          task target => context.iidfile
        end
        task :build => %I[build:#{target}]

        namespace :clean do
          task target do
            rm_rf context.iidfile
          end
        end
        task(:clean).prereqs.unshift :"clean:#{target}"

        namespace :clobber do
          task target => %I[clean:#{target}] do
            sh "docker image rm --force #{context.tag}"
          end
        end
        task(:clobber).prereqs.unshift :"clobber:#{target}"

        namespace :run do
          task target, [:cmd] => context.iidfile do
            puts "docker run $(cat #{context.iidfile})"
          end
        end

        namespace :shell do
          task target, [:sh] => context.iidfile do
            puts "docker run $(cat #{context.iidfile})"
          end
        end
      end
    end

    ##
    # Rum base task block.
    #
    # Example
    #   rum :amancevice/rumrunner do
    #     tag %x(git describe --tags --always)
    #     # ...
    #   end
    #
    def rum(*args, &block)
      name, _, deps = Rake.application.resolve_args(args)
      path, home = deps
      Manifest.new(name: name, path: path, home: home).install(&block)
    end
  end
end

self.extend Rum::DSL
