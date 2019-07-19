RSpec.describe Cargofile::Application do
  it "::new" do
    app = Cargofile::Application.new
    expect(app.name).to eq("cargo")
  end

  it "#init" do
    app = Cargofile::Application.new
    expect(app.top_level_tasks).to eq([])
    app.init "cargo", []
    expect(app.top_level_tasks).to eq(["default"])
  end
end
