RSpec.describe Rum::Application do
  it "::new" do
    app = Rum::Application.new
    expect(app.name).to eq("rum")
  end

  it "#init" do
    app = Rum::Application.new
    expect(app.top_level_tasks).to eq([])
    app.init "rum", []
    expect(app.top_level_tasks).to eq(["default"])
  end
end
