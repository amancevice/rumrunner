module Cargofile
  module Buildable
    extend Forwardable

    def_delegators :build, :method_missing, :path

    def build
      @build ||= Docker::Build.new
    end
  end

  module Taggable
    extend Forwardable

    def_delegator :image, :tag

    def image
      @image ||= Docker::Image.new
    end
  end

  module Stageable
    attr_accessor :stages

    def stage(name, &block)
      @image.tag SecureRandom.hex(6) if @image.tag.nil?
      bld = @build.clone
      img = @image.clone
      bld.target name
      img.tag "#{img.tag}-#{name}"
      stages << Stage.new(
        name:  name,
        build: bld,
        image: img,
        dir:   dir,
        shell: shell,
        &block
      )
    end

    def stages
      @stages ||= []
    end
  end

  module Artifactable
    attr_accessor :artifacts

    def artifact(name, &block)
      artifacts << Artifact.new(name: name, &block)
    end

    def artifacts
      @artifacts ||= []
    end
  end

  class Base
    include Buildable
    include Taggable
    include Rake::DSL if defined? Rake::DSL

    attr_accessor :name, :dir

    def initialize(name:nil, build:nil, image:nil, dir:nil, shell:nil, &block)
      @name  = name  || SecureRandom.hex(6)
      @build = build || Docker::Build.new
      @image = image || Docker::Image.parse(@name.to_s)
      @dir   = dir   || ".docker"
      @shell = shell || "/bin/bash"
      yield self if block_given?
    end

    def dir(value = nil)
      @dir = value || @dir
    end

    def name(value = nil)
      @name = value || @name
    end

    def shell(value = nil)
      @shell = value || @shell
    end
  end

  class Manifest < Base
    include Stageable

    def install
      stages.map(&:install)

      stages.map(&:name).zip([@dir] + stages.map(&:name)[0..-2]).each do |a,b|
        task a => b
      end

      namespace :clean do
        desc "Remove any temporary images"
        task :images do
          Dir[File.join @dir.to_s, "**"].each do |iidfile|
            sh "docker", "image", "rm", "-f", File.read(iidfile)
          end
        end
      end
      task :clean => :"clean:images"
    end
  end

  class Stage < Base
    include Artifactable

    def install
      @build.options[:tag]     ||= [@image.to_s]
      @build.options[:iidfile] ||= [File.join(@dir.to_s, @image.tag)]

      unless CLEAN.include? @dir.to_s
        directory @dir.to_s
        CLEAN.include(@dir.to_s)
      end

      iidfile = @build.options[:iidfile].last

      file iidfile => @dir do
        sh *@build.to_a
      end
      CLEAN.include(iidfile)

      artifacts.map{|x| x.install(@name, iidfile) }

      desc "Build through #{@name} stage"
      task @name => iidfile

      namespace @name do
        desc "Shell into #{@name} stage"
        task :shell => @name do
          digest  = File.read(iidfile)
          command = Docker::Run.new(image: digest, cmd: @shell) do |run|
            run.rm
            run.interactive
            run.tty
          end
          sh *command.to_a
        end
      end
    end
  end

  class Artifact
    include Rake::DSL if defined? Rake::DSL

    attr_accessor :name, :run

    def initialize(name:, &block)
      @name = name
      @run  = Docker::Run.new(cmd: ["cat", @name]).rm
      yield @run if block_given?
    end

    def install(stage, iidfile)
      path = File.split(name).first

      unless path == "."
        directory path
        CLOBBER.include(path)
      end

      file @name => [iidfile, path] do
        @run.image = File.read(iidfile)
        @run.cmd  += [">", @name]
        sh @run.to_s
      end
      CLOBBER.include(@name)
      task stage => @name
    end
  end
end
