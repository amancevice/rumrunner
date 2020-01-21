require "forwardable"
require "rake"

module Rum
  class Manifest
    extend Forwardable
    include Rake::DSL

    def_delegators :dockerfile, :path, :file, :targets

    def initialize(image = nil, **options)
      @image = image
      @path  = options[:path]
      @file  = options[:file]
      @home  = options[:home]
    end

    def digest(target = nil)
      iid = iidfile(target)
      File.read(iid) if File.exist?(iid)
    end

    def dockerfile(target = nil)
      Docker::Dockerfile.new(@path, @file, target)
    end

    def env
      @env ||= []
    end

    def iidfile(target = nil)
      iidhome  = @home || ENV["RUM_HOME"] || ".docker"
      iidpath  = image.family
      iidfile  = image.tag || "latest"
      iidfile += "-#{target}" unless target.nil?
      File.join(iidhome, iidpath, iidfile)
    end

    def iidfiles
      targets.map{|target| iidfile(target) }
    end

    def image(target = nil)
      name  = @image || File.basename(Dir.pwd)
      name += "-#{target}" unless target.nil?
      Docker::Image.parse(name)
    end

    def install
      install_default_shells
      # install_build
      # install_default
      # install_clean
      # install_clobber
      self
    end

    private

    def install_default_shells
      Rum.application.tasks.select{|t| t.is_a? Rum::StageTask }.map do |t|
        t.install_default_shell
      end
    end

    def install_build
      iids = iidfiles.append(iidfile).reverse
      iids.zip(iids[1..-1]).each do |f,dep|
        Rake::FileTask.define_task(f => dep)
      end

      Rake::FileTask.define_task(iidfile) do
        build = Docker::Build.new(path,
          build_arg: env,
          iidfile:   iidfile,
          tag:       image,
        )
        sh build.to_s
      end
    end

    def install_default
      task :default => iidfile
    end

    def install_clean
      task(:clean) { rm iidfile }
    end

    def install_clobber
      task :clobber do
        # TODO
        puts "TODO"
      end
    end
  end
end
