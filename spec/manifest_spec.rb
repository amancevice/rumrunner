RSpec.describe Rum::Manifest do
  Rum::Manifest.new(:name => :"registry:5000/username/name") do
    tag      "1.2.3"
    stage    :build
    stage    :test => :build

    artifact "fizz" => :build

    shell :build

    run :jazz
    build :fuzz

    default "fizz"
  end.install

  describe "::new" do
    it "defines a whole bunch of tasks" do
      ret = Hash[Rake::Task.tasks.collect{|x| [x.name, x.class] }]
      exp = {
        ".docker"                                         => Rake::FileCreationTask,
        ".docker/registry:5000"                           => Rake::FileCreationTask,
        ".docker/registry:5000/username"                  => Rake::FileCreationTask,
        ".docker/registry:5000/username/name:1.2.3-build" => Rake::FileTask,
        ".docker/registry:5000/username/name:1.2.3-test"  => Rake::FileTask,
        "build"                                           => Rake::Task,
        "build:clean"                                     => Rake::Task,
        "build:shell"                                     => Rake::Task,
        "clean"                                           => Rake::Task,
        "clobber"                                         => Rake::Task,
        "default"                                         => Rake::Task,
        "fizz"                                            => Rake::FileTask,
        "fuzz"                                            => Rake::Task,
        "jazz"                                            => Rake::Task,
        "test"                                            => Rake::Task,
        "test:clean"                                      => Rake::Task,
        "test:shell"                                      => Rake::Task,
      }
      expect(ret).to eq(exp)
    end
  end

  describe "#build" do
    it "runs a Docker build command" do
      ret = Rake::Task[:fuzz].invoke.first.call
      exp = ["docker build ."]
      expect(ret).to eq(exp)
    end
  end

  describe "#run" do
    it "runs a Docker run command" do
      ret = Rake::Task[:jazz].invoke.first.call
      exp = ["docker run registry:5000/username/name:1.2.3"]
      expect(ret).to eq(exp)
    end
  end

  describe "#stage" do
  end

  describe "#artifact" do
  end

  describe "#shell" do
  end

  describe "#install" do
  end
end
