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
end
