RSpec.describe Rum::Application do
  describe "::new" do
    it "initializes with name `rum`" do
      expect(subject.name).to eq("rum")
    end
  end

  describe "#init" do
    it "initializes the Rum::Application" do
      expect { subject.init "rum", [] }.to \
      change { subject.top_level_tasks }
        .from([])
        .to(["default"])
    end
  end

  describe "#rumfile?" do
    it "finds a Rumfile" do
      allow(File).to receive(:size?).and_return(1)
      expect(subject.rumfile?).to be true
    end

    it "does not find a Rumfile" do
      allow(File).to receive(:size?).and_return(nil)
      expect(subject.rumfile?).to be false
    end
  end

  describe "#run" do
    it "runs the init script" do
      allow(Rum).to receive(:init).and_return("init called")
      allow(subject).to receive(:rumfile?).and_return(false)
      expect(subject.run ["init"]).to eq("init called")
    end

    it "prints the version info (--version)" do
      expect { subject.run ["--version"] }.to output("rum, version #{Rum::VERSION}\n").to_stdout
    end

    it "prints the version info (-V)" do
      expect { subject.run ["-V"] }.to output("rum, version #{Rum::VERSION}\n").to_stdout
    end

    it "runs the application" do
      allow_any_instance_of(Rake::Application).to receive(:run).and_return("run called")
      expect(subject.run).to eq("run called")
    end
  end
end
