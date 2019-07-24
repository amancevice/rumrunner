RSpec.describe Rum::Docker::AttrCallable do
  class Test
    extend Rum::Docker::AttrCallable

    attr_method_accessor :fizz
  end

  describe "::attr_method_accessor" do
    it "Allows an attr to be set by calling it as a method" do
      ret = Test.new
      ret.fizz :buzz
      expect(ret.fizz).to eq(:buzz)
    end
  end
end

RSpec.describe Rum::Docker::Options do
  describe "::new" do
    it "can be expressed as a Hash" do
      ret = Rum::Docker::Options.new.flag(:value).flag(:key => :value)
      exp = {:flag => [:value, {:key => :value}]}
      expect(ret.to_h).to eq(exp)
    end
  end

  describe "#each" do
    it "converts to an Array of words" do
      ret = Rum::Docker::Options.new.flag(:value).flag(:key => :value)
      exp = %w[--flag value --flag key=value]
      expect(ret.to_a).to eq(exp)
    end
  end

  describe "#method_missing" do
    it "forwards methods to set options" do
      ret = Rum::Docker::Options.new.fizz(true)
      expect(ret.to_h.keys).to eq([:fizz])
    end
  end

  describe "#to_s" do
    it "converts to a string" do
      ret = Rum::Docker::Options.new.flag(:value).flag(:key => :value)
      exp = "--flag value --flag key=value"
      expect(ret.to_s).to eq(exp)
    end
  end
end

RSpec.describe Rum::Docker::Build do
  describe "::new" do
    it "initializes a new build command" do
      expect(Rum::Docker::Build.new).not_to be nil
    end
  end

  describe "#each" do
    it "converts to an Array of Docker build command words" do
      expect(Rum::Docker::Build.new.to_a).to eq(%w[docker build .])
    end
  end

  describe "#method_missing" do
    it "forwards missing methods to the Options instance variable" do
      ret = Rum::Docker::Build.new.label(:FIZZ)
      exp = {label: [:FIZZ]}
      expect(ret.options.to_h).to eq(exp)
    end
  end

  describe "#to_s" do
    it "converts to a Docker build command string" do
      ret = Rum::Docker::Build.new do
        @options.build_arg :FIZZ => "buzz"
        @options.build_arg :BUZZ
      end
      exp = "docker build --build-arg FIZZ=buzz --build-arg BUZZ ."
      expect(ret.to_s).to eq(exp)
    end
  end

  describe "#with_defaults" do
    it "applies defaults if not provided in initialization" do
      ret = Rum::Docker::Build.new do
        tag    :fizz
        target :buzz
      end.with_defaults(tag: "foo", target: "bar", :jazz => :fuzz)
      exp = {:tag=>[:fizz], :target=>[:buzz], :jazz => [:fuzz]}
      expect(ret.options.to_h).to eq(exp)
    end
  end
end

RSpec.describe Rum::Docker::Run do
  describe "::new" do
    it "initializes a new run command" do
      expect(Rum::Docker::Run.new).not_to be nil
    end
  end

  describe "#each" do
    it "converts to an Array of Docker run command words" do
      ret = Rum::Docker::Run.new image: "fizz"
      expect(ret.to_a).to eq(%w[docker run fizz])
    end
  end

  describe "#to_s" do
    it "converts to a Docker run command string" do
      ret = Rum::Docker::Run.new(image: "fizz") do |r|
        r.options.rm false
        r.cmd %w[echo hello, world]
      end
      exp = "docker run --rm=false fizz echo hello, world"
      expect(ret.to_s).to eq(exp)
    end
  end

  describe "#with_defaults" do
    it "applies defaults if not provided in initialization" do
      ret = Rum::Docker::Run.new do
        rm false
      end.with_defaults(rm: true)
      exp = {:rm=>[false]}
      expect(ret.options.to_h).to eq(exp)
    end
  end
end

RSpec.describe Rum::Docker::Image do
  describe "::parse" do
    it "parses 'image'" do
      exp = "image"
      ret = Rum::Docker::Image.parse(exp).to_s
      expect(ret).to eq("#{exp}:latest")
    end

    it "parses 'username/image'" do
      exp = "username/image"
      ret = Rum::Docker::Image.parse(exp).to_s
      expect(ret).to eq("#{exp}:latest")
    end

    it "parses 'image:tag'" do
      exp = "image:tag"
      ret = Rum::Docker::Image.parse(exp).to_s
      expect(ret).to eq(exp)
    end

    it "parses 'username/image:tag'" do
      exp = "username/image:tag"
      ret = Rum::Docker::Image.parse(exp).to_s
      expect(ret).to eq(exp)
    end

    it "parses 'registry:5000/username/image'" do
      exp = "registry:5000/username/image"
      ret = Rum::Docker::Image.parse(exp).to_s
      expect(ret).to eq("#{exp}:latest")
    end

    it "parses 'registry:5000/username/image:tag'" do
      exp = "registry:5000/username/image:tag"
      ret = Rum::Docker::Image.parse(exp).to_s
      expect(ret).to eq(exp)
    end
  end

  describe "#each" do
    it "converts to a compacted Array of [registry, username, name, tag]" do
      ret = Rum::Docker::Image.parse "registry/user/fizz:latest"
      exp = %w[registry user fizz latest]
      expect(ret.to_a).to eq(exp)
    end
  end

  describe "#family" do
    it "gets the image name without the tag" do
      ret = Rum::Docker::Image.parse "registry/user/fizz:latest"
      exp = "registry/user/fizz"
      expect(ret.family).to eq(exp)
    end
  end

  describe "#to_s" do
    it "converts to a fully-qualified Docker tag" do
      ret = Rum::Docker::Image.parse "registry/user/fizz:latest"
      exp = "registry/user/fizz:latest"
      expect(ret.to_s).to eq(exp)
    end
  end
end
