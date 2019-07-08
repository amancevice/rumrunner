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
      build = @build.clone
      image = @image.clone
      build.target name
      image.tag "#{image.tag}-#{name}"
      stages << Stage.new(name: name, build: build, image: image, &block)
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

=begin
      desc 'Remove Docker images and iidfiles'
      task :clean do
        Dir[File.join @dir.to_s, "**"].each do |iidfile|
          digest = File.read iidfile
          sh "docker", "image", "rm", "-f", digest
          File.delete iidfile
        end
        stages.map(&:artifacts).flatten.each do |artifact|
          File.delete artifact.name if File.exists?(artifact.name)
        end
        Dir.delete(@dir.to_s) if Dir.exists?(@dir.to_s)
      end
=end
    end
  end

  class Stage < Base
    include Artifactable

    def install
      @build.options[:tag]     ||= [@image.to_s]
      @build.options[:iidfile] ||= [File.join(@dir.to_s, @image.tag)]

      iidfile = @build.options[:iidfile].last

      directory @dir.to_s
      CLEAN.include(@dir)

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
          digest = File.read(iidfile)
          sh "docker", "run", "--rm", "-it", digest, @shell
        end
      end
    end
  end

  class Artifact
    include Rake::DSL if defined? Rake::DSL

    attr_accessor :name, :cmd

    def initialize(name:, cmd:nil, &block)
      @name = name
      @cmd  = cmd || ["cat", @name]
      yield self if block_given?
    end

    def cmd(*values)
      @cmd = values.empty? ? @cmd : values
    end

    def install(stage, iidfile)
      path, name = File.split(@name)

      directory path
      CLOBBER.include(path)

      file @name => [iidfile, path] do
        digest = File.read(iidfile)
        sh "docker run --rm #{digest} #{@cmd.join " "} > #{@name}"
      end
      CLOBBER.include(@name)
      task stage => @name
    end
  end
end
