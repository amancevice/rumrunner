RSpec.describe Rum::Manifest do
  let(:tasks) do
    {
      ".docker"                                         => Rake::FileCreationTask,
      ".docker/registry:5000"                           => Rake::FileCreationTask,
      ".docker/registry:5000/username"                  => Rake::FileCreationTask,
      ".docker/registry:5000/username/name:1.2.3-build" => Rake::FileTask,
      ".docker/registry:5000/username/name:1.2.3-test"  => Rake::FileTask,
      "build"                                           => Rake::Task,
      "clean"                                           => Rake::Task,
      "clean:build"                                     => Rake::Task,
      "clean:test"                                      => Rake::Task,
      "clobber"                                         => Rake::Task,
      "default"                                         => Rake::Task,
      "fuzz"                                            => Rake::Task,
      "jazz"                                            => Rake::Task,
      "pkg"                                             => Rake::FileCreationTask,
      "pkg/fizz.zip"                                    => Rake::FileTask,
      "shell:build"                                     => Rake::Task,
      "shell:test"                                      => Rake::Task,
      "test"                                            => Rake::Task,
    }
  end

  subject do
    Rum::Manifest.new name: "registry:5000/username/name" do
      tag      "1.2.3"
      env      :FIZZ => "buzz"
      stage    :build
      stage    :test => :build
      artifact "pkg/fizz.zip" => :build
      shell    :build
      run      :jazz
      build    :fuzz
      default  "pkg/fizz.zip"
    end
  end

  before { subject.install }

  describe "::new" do
    it "defines a whole bunch of tasks" do
      expect(Hash[Rake::Task.tasks.map{|x| [x.name, x.class] }]).to eq tasks
    end
  end

  describe "#build" do
    it "runs a Docker build command" do
      expect(Rake::Task[:fuzz].invoke.first.call).to eq ["docker build ."]
    end
  end

  describe "#run" do
    it "runs a Docker run command" do
      expect(Rake::Task[:jazz].invoke.first.call).to eq ["docker run registry:5000/username/name:1.2.3"]
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

  describe "#build_options" do
    it "returns the default options" do
      expect(subject.send(:build_options).to_a).to eq ["--build-arg", "FIZZ=buzz"]
    end
  end

  describe "#run_options" do
    it "returns the default options" do
      expect(subject.send(:run_options).to_a).to eq ["--env", "FIZZ=buzz"]
    end
  end

  describe "#task_name" do
    after { ENV.delete "RUM_TASK_NAMES" }

    it "defaults to VERB_FIRST" do
      expect(subject.send :task_name, clean: "stage").to eq :"clean:stage"
    end

    it "uses to VERB_FIRST" do
      ENV["RUM_TASK_NAMES"] = "VERB_FIRST"
      expect(subject.send :task_name, clean: "stage").to eq :"clean:stage"
    end

    it "uses to STAGE_FIRST" do
      ENV["RUM_TASK_NAMES"] = "STAGE_FIRST"
      expect(subject.send :task_name, clean: "stage").to eq :"stage:clean"
    end
  end
end
