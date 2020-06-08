# frozen_string_literal: true
require "rake"

require "rumrunner/manifest"
require "rumrunner/tasks"

module Rum

  ##
  # Defines the DSL methods for Rum Runner.
  module DSL
    include Rake::DSL

    private

    # -- methods that open a new context

    ##
    # Main context block. Analagous to Rake namespace.
    #
    # Example:
    #   repo :namespace, name: "user/img", tag: "1.2.3", iidpath: ".docker" do
    #     # ...
    #   end
    def _repo(name = nil, context:nil, dockerfile:nil, image:nil, **options, &block)
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
    # Docker stage
    def _stage(*args, &block)
      app = Rum.application
      target, task_args, deps, * = app.resolve_args(args)

      app.in_context(target: target.to_s, tag: target.to_s) do |context|

        namespace :build do
          iidpath = File.dirname(context.iidfile)
          directory iidpath
          file context.iidfile, task_args => deps, order_only: iidpath do |f,args|
            iidfile = "#{f.name}-#{Time.now.to_i}"
            sh <<~EOS
              docker build \
              --iidfile #{iidfile} \
              --tag #{context.tag} \
              --target #{target} \
              #{context.path}
            EOS
            cp iidfile, f.name
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
          task target do
            Dir.glob("#{context.iidfile}*").sort.reverse.each do |iidfile|
              sh "docker image rm --force #{context.digest}"
              rm_rf iidfile
            end
          end
        end
        task(:clobber).prereqs.unshift :"clobber:#{target}"

        namespace :run do
          task target, [:cmd] => context.iidfile do |t,args|
            sh "docker run --rm #{context.digest} #{args.cmd}"
          end
        end

        namespace :shell do
          task target, [:sh] => context.iidfile do |t,args|
            sh "docker run --interactive --rm --tty #{context.digest} #{args.sh}"
          end
        end
      end
    end

    def _export(*args, &block)
      task_name, task_args, deps, * = Rum.application.resolve_args(args)
      namespace :export do
        deps.each do |dep|
          file(dep, task_args, &block).enhance(app.current_context.iidfile) do |f,args|
            puts f.name
          end
        end
        task task_name => deps
      end
      task :export => %I[export:#{task_name}]
    end

    # -- methods that enhance the current context

    def context(path)
      puts "CONTEXT    #{args}"
      Rum.application.current_context.context = path
    end

    def dockerfile(name)
      puts "DOCKERFILE #{args}"
      Rum.application.current_context.dockerfile = name
    end

    def env(value)
      puts "ENV        #{args}"
      Rum.application.current_context.env << value
    end

    def image(image)
      puts "IMAGE      #{args}"
      Rum.application.current_context.image = image
    end

    def repo(repo)
      puts "REPO       #{args}"
      Rum.application.current_context.repo = repo
    end

    # -- methods that define tasks

    def build(*args, &block)
      BuildTask.define_task(*args, &block)
    end

    def run(*args, &block)
      RunTask.define_task(*args, &block)
    end

    def stage(*args, &block)
      StageTask.define_task(*args, &block)
    end

    def export(*args, &block)
      ExportTask.define_task(*args, &block)
    end
  end
end

self.extend Rum::DSL
