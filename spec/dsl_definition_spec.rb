RSpec.describe Rum::DSL do
  class TestDSL
    extend Rum::DSL
  end

  describe "#rum" do
    ret = TestDSL.send(:rum, :image_name)

    it "returns an instance of Rum::Manifest" do
      expect(ret.class).to be Rum::Manifest
    end

    it "has the correct image name" do
      expect(ret.image.to_s).to eq("image_name:latest")
    end

    it "has the correct root" do
      expect(ret.root).to eq(".docker")
    end
  end
end
