module Cargofile
  class Manifest
    extend Forwardable
    include Rake::DSL if defined? Rake::DSL

    def_delegator :@root, :to_s, :root
    def_delegators :@image, :registry, :username, :name, :tag

    def initialize(name:, root:nil, &block)
      @name      = name
      @root      = root || :".docker"
      @image     = Docker::Image.parse(name)
      @env       = []
      @targets   = {}
      @artifacts = {}
      @shells    = {}
      instance_eval(&block) if block_given?
    end

    def env(key_val)
      @env << key_val
    end

    def target(name_deps, &block)
      name, deps = name_deps.is_a?(Hash) ? name_deps.first : [name_deps, nil]
      image      = "#{@image}-#{name}"
      iidfile    = File.join(root, image)
      options    = build_options.iidfile(iidfile).tag(image).target(name)
      @shells[name]  = Docker::Run.new.interactive(true).rm(true).tty(true).cmd("/bin/bash")
      @targets[name] = {
        iidfile: iidfile,
        prereqs: [deps].flatten.compact,
        command: Docker::Build.new(options: options.to_h, &block),
      }
    end

    def artifact(name_deps, &block)
      name, deps = name_deps.is_a?(Hash) ? name_deps.first : [name_deps, nil]
      options    = run_options.rm(true)
      @artifacts[name] = {
        prereqs: [deps].flatten.compact,
        command: Docker::Run.new(options: options.to_h, &block)
      }
    end

    def shell(name_deps, &block)
      name, deps = name_deps.is_a?(Hash) ? name_deps.first : [nil, name_deps]
      options    = run_options.interactive(true).rm(true).tty(true)
      command    = Docker::Run.new(options: options.to_h, &block)
      command.cmd name unless name.nil?
      @shells[deps] = command
    end

    def install
      directory root

      @targets  .each{|name, target| install_target   name, target }
      @artifacts.each{|name, target| install_artifact name, target }
      @shells   .each{|name, target| install_shell    name, target }

      install_clean
    end

    private

    def build_options
      opts = Docker::OptionCollection.new
      @env.each{|x| opts.build_arg x }
      opts
    end

    def run_options
      opts = Docker::OptionCollection.new
      @env.each{|x| opts.env x }
      opts
    end

    def install_target(name, target)
      command = target[:command]
      iidfile = target[:iidfile]
      iidpath = File.split(iidfile).first
      prereqs = target[:prereqs].map{|x| @targets[x][:iidfile] }.flatten
      prereqs << iidpath

      directory iidpath

      file iidfile => prereqs do
        sh command.to_s
      end

      desc "Build `#{name}` stage"
      task name => iidfile

      preclean = @targets.select{|k,v| v[:prereqs].include? name }.keys.map{|x| :"#{x}:clean" }
      desc "Remove any temporary images and products from `#{name}` stage"
      task :"#{name}:clean" => preclean do
        if File.exists? iidfile
          sh "docker", "image", "rm", "--force", File.read(iidfile)
          rm iidfile
        end
      end
    end

    def install_artifact(name, target)
      path    = File.split(name).first
      command = target[:command]
      iidfile = target[:prereqs].map{|x| @targets[x][:iidfile] }.flatten.first

      directory path

      desc "Build `#{name}`"
      file name => [iidfile, path] do
        command.image File.read(iidfile)
        command.cmd "cat", name if command.cmd.nil?
        sh "#{command} > #{name}"
      end
    end

    def install_shell(name, command)
      iidfile = @targets[name][:iidfile]

      desc "Shell into `#{name}` stage"
      task :"#{name}:shell" => iidfile do
        command.image File.read(iidfile)
        sh command.to_s
      end
    end

    def install_clean
      desc "Remove any temporary images and products"
      task :clean do
        Dir[File.join root, "**/*"].reverse.each do |name|
          sh "docker", "image", "rm", "--force", File.read(name) if File.file?(name)
          rm_r name
        end
        rm_r root
      end
    end
  end
end
