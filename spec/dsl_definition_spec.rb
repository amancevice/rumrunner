class TestDSL
  extend Rum::DSL
end

RSpec.describe Rum::DSL do
  subject { TestDSL.send :rum, :image_name }

  describe "#rum" do
    it "returns an instance of Rum::Manifest" do
      expect(subject.class).to be Rum::Manifest
    end

    it "has the correct image name" do
      expect(subject.image.to_s).to eq "image_name:latest"
    end

    it "has the correct root" do
      expect(subject.root).to eq ".docker"
    end
  end
end
