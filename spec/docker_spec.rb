class Test
  extend Rum::Docker::AttrCallable
  attr_method_accessor :fizz
end

RSpec.describe Rum::Docker::AttrCallable do
  subject { Test.new }

  describe "::attr_method_accessor" do
    it "sets an attr by calling it as a method" do
      expect { subject.fizz :buzz }.to \
      change { subject.instance_variables }.from([]).to([:@fizz])
    end

    it "gets an attr by calling it as a method" do
      subject.fizz :buzz
      expect(subject.fizz).to eq :buzz
    end
  end
end

RSpec.describe Rum::Docker::Options do
  let(:options) { {:flag => [:value, {:key => :value}]} }

  subject { Rum::Docker::Options.new options }

  describe "#each" do
    it "converts to an Array of words" do
      expect(subject.to_a).to eq(%w[--flag value --flag key=value])
    end
  end

  describe "#method_missing" do
    it "forwards methods to set options" do
      subject.fizz true
      subject.fizz false
      expect(subject[:fizz]).to eq [true, false]
    end
  end

  describe "#to_h" do
    it "can be expressed as a Hash" do
      expect(subject.to_h).to eq options
    end
  end

  describe "#to_s" do
    it "converts to a string" do
      expect(subject.to_s).to eq "--flag value --flag key=value"
    end
  end
end

RSpec.describe Rum::Docker::Build do
  describe "#each" do
    it "converts to an Array of Docker build command words" do
      expect(subject.to_a).to eq %w[docker build .]
    end
  end

  describe "#method_missing" do
    it "forwards missing methods to the Options instance variable" do
      expect { subject.label :FIZZ }.to \
      change { subject.label }.from([]).to([:FIZZ])
    end
  end

  describe "#to_s" do
    it "converts to a Docker build command string" do
      subject.build_arg :FIZZ => "buzz"
      subject.build_arg :BUZZ
      expect(subject.to_s).to eq "docker build --build-arg FIZZ=buzz --build-arg BUZZ ."
    end
  end

  describe "#with_defaults" do
    subject { Rum::Docker::Build.new.tag(:fizz).target(:buzz).with_defaults(tag: "foo", target: "bar", :jazz => :fuzz) }

    it "applies defaults if not provided in initialization" do
      expect(subject.options.to_h).to include tag: [:fizz], target: [:buzz], jazz: [:fuzz]
    end
  end
end

RSpec.describe Rum::Docker::Run do
  subject { Rum::Docker::Run.new image: "fizz" }

  describe "#each" do
    it "converts to an Array of Docker run command words" do
      expect(subject.to_a).to eq %w[docker run fizz]
    end
  end

  describe "#to_s" do
    let(:subject_with_opts) { subject.rm(false).cmd(%w[echo hello, world]) }

    it "converts to a Docker run command string" do
      expect(subject_with_opts.to_s).to eq "docker run --rm=false fizz echo hello, world"
    end
  end

  describe "#with_defaults" do
    let(:subject_with_defaults) { subject.rm(false).with_defaults(rm: true) }

    it "applies defaults if not provided in initialization" do
      expect(subject_with_defaults.options.to_h).to include rm: [false]
    end
  end
end

RSpec.describe Rum::Docker::Image do
  let(:image)                            { "image" }
  let(:image_tag)                        { "image:tag" }
  let(:username_image)                   { "username/image" }
  let(:username_image_tag)               { "username/image:tag" }
  let(:registry_5000_username_image)     { "registry:5000/username/image" }
  let(:registry_5000_username_image_tag) { "registry:5000/username/image:tag" }

  subject { Rum::Docker::Image.new name: "fizz", registry: "registry", username: "user" }

  describe "::parse" do
    subject { Rum::Docker::Image }

    it "parses 'image'" do
      expect(subject.parse(image).to_s).to eq "#{image}:latest"
    end

    it "parses 'username/image'" do
      expect(subject.parse(username_image).to_s).to eq "#{username_image}:latest"
    end

    it "parses 'image:tag'" do
      expect(subject.parse(image_tag).to_s).to eq image_tag
    end

    it "parses 'username/image:tag'" do
      expect(subject.parse(username_image_tag).to_s).to eq username_image_tag
    end

    it "parses 'registry:5000/username/image'" do
      expect(subject.parse(registry_5000_username_image).to_s).to eq "#{registry_5000_username_image}:latest"
    end

    it "parses 'registry:5000/username/image:tag'" do
      expect(subject.parse(registry_5000_username_image_tag).to_s).to eq registry_5000_username_image_tag
    end
  end

  describe "#each" do
    it "converts to a compacted Array of [registry, username, name, tag]" do
      expect(subject.to_a).to eq %w[registry user fizz latest]
    end
  end

  describe "#family" do
    it "gets the image name without the tag" do
      expect(subject.family).to eq "registry/user/fizz"
    end
  end

  describe "#to_s" do
    it "converts to a fully-qualified Docker tag" do
      expect(subject.to_s).to eq "registry/user/fizz:latest"
    end
  end
end
