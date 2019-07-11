RSpec.describe "#cargo" do
  it "installs the tasks" do
    ret = cargo :fizz => :dir
    expect(ret.class).to eq(Cargofile::Manifest)
  end
end
