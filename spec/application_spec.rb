RSpec.describe Rum::Application do
  describe "::new" do
    it "initializes an instance of a Rum::Application" do
      app = Rum::Application.new
      expect(app.name).to eq("rum")
    end
  end

  describe "#init" do
    it "initializes the Rum::Application" do
      app = Rum::Application.new
      expect(app.top_level_tasks).to eq([])
      app.init "rum", []
      expect(app.top_level_tasks).to eq(["default"])
    end
  end
end
