module Cargofile
  class Manifest
    extend Forwardable
    include Rake::DSL if defined? Rake::DSL

    def_delegator :@env, :<<, :env
    def_delegator :@root, :to_s, :root
    def_delegators :@image, :registry, :username, :name, :tag, :to_s

    def initialize(name:, root:nil, &block)
      @root      = root || :".docker"
      @image     = Docker::Image.parse(name)
      @env       = []
      @stages    = {}
      @artifacts = {}
      @shells    = {}
      instance_eval(&block) if block_given?
    end

    def stage(name_deps, &block)
      name, deps = name_deps.is_a?(Hash) ? name_deps.first : [name_deps, nil]

      image   = "#{@image}-#{name}"
      iidfile = File.join(root, image)
      prereqs = [deps].flatten.compact
      options = build_options.iidfile(iidfile).tag(image).target(name)
      command = Docker::Build.new(options: options.to_h, &block)

      @shells[name] = Docker::Run.new.interactive(true).rm(true).tty(true).cmd("/bin/bash")
      @stages[name] = {iidfile: iidfile, prereqs: prereqs, command: command}
    end

    def artifact(name_deps, &block)
      name, deps = name_deps.is_a?(Hash) ? name_deps.first : [name_deps, nil]

      options = run_options.rm(true)
      prereqs = [deps].flatten.compact
      command = Docker::Run.new(options: options, &block)

      @artifacts[name] = {prereqs: prereqs, command: command}
    end

    def shell(name_deps, &block)
      name, deps = name_deps.is_a?(Hash) ? name_deps.first : [nil, name_deps]

      options = run_options.interactive(true).rm(true).tty(true)
      command = Docker::Run.new(options: options.to_h, &block)
      command.cmd name unless name.nil?

      @shells[deps] = command
    end

    def install
      directory root

      @stages   .each{|name, target| install_stage    name, target }
      @artifacts.each{|name, target| install_artifact name, target }
      @shells   .each{|name, target| install_shell    name, target }

      install_clean
    end

    private

    def build_options
      Docker::OptionCollection.new build_arg: @env
    end

    def run_options
      Docker::OptionCollection.new env: @env
    end

    def install_stage(name, target)
      command = target[:command]
      iidfile = target[:iidfile]
      iidpath = File.split(iidfile).first
      prereqs = target[:prereqs].map{|x| @stages[x][:iidfile] }.flatten
      prereqs << iidpath

      directory iidpath

      file iidfile => prereqs do
        sh command.to_s
      end

      desc "Build `#{name}` stage"
      task name => iidfile

      preclean = @stages.select{|k,v| v[:prereqs].include? name }.keys.map{|x| :"#{x}:clean" }
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
      iidfile = target[:prereqs].map{|x| @stages[x][:iidfile] }.flatten.first

      directory path

      desc "Build `#{name}`"
      file name => [iidfile, path] do
        command.image File.read(iidfile)
        command.cmd "cat", name if command.cmd.nil?
        sh "#{command} > #{name}"
      end
      task :clean do
        rm_r name if File.exists?(name)
      end
    end

    def install_shell(name, command)
      iidfile = @stages[name][:iidfile]

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
        rm_r root if Dir.exists?(root)
      end
    end
  end
end
