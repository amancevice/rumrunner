RSpec.describe Cargofile::Docker::AttrCallable do
  class Test
    extend Cargofile::Docker::AttrCallable

    attr_method_accessor :fizz
  end

  it "::attr_method_accessor" do
    ret = Test.new
    ret.fizz :buzz
    expect(ret.fizz).to eq(:buzz)
  end
end

RSpec.describe Cargofile::Docker::Options do
  it "#new" do
    ret = Cargofile::Docker::Options.new.flag(:value).flag(:key => :value)
    exp = {:flag => [:value, {:key => :value}]}
    expect(ret.to_h).to eq(exp)
  end

  it "#each" do
    ret = Cargofile::Docker::Options.new.flag(:value).flag(:key => :value)
    exp = %w[--flag value --flag key=value]
    expect(ret.to_a).to eq(exp)
  end

  it "#method_missing" do
    ret = Cargofile::Docker::Options.new.fizz(true)
    expect(ret.to_h.keys).to eq([:fizz])
  end

  it "#to_s" do
    ret = Cargofile::Docker::Options.new.flag(:value).flag(:key => :value)
    exp = "--flag value --flag key=value"
    expect(ret.to_s).to eq(exp)
  end
end

RSpec.describe Cargofile::Docker::Build do
  it "#initialize" do
    expect(Cargofile::Docker::Build.new).not_to be nil
  end

  it "#each" do
    expect(Cargofile::Docker::Build.new.to_a).to eq(%w[docker build .])
  end

  it "#method_missing" do
    ret = Cargofile::Docker::Build.new.label(:FIZZ)
    exp = {label: [:FIZZ]}
    expect(ret.options.to_h).to eq(exp)
  end

  it "#to_s" do
    ret = Cargofile::Docker::Build.new do |b|
      b.options.build_arg :FIZZ => "buzz"
      b.options.build_arg :BUZZ
    end
    exp = "docker build --build-arg FIZZ=buzz --build-arg BUZZ ."
    expect(ret.to_s).to eq(exp)
  end

  it "#with_defaults" do
    ret = Cargofile::Docker::Build.new do
      tag    :fizz
      target :buzz
    end.with_defaults(tag: "foo", target: "bar", :jazz => :fuzz)
    exp = {:tag=>[:fizz], :target=>[:buzz], :jazz => [:fuzz]}
    expect(ret.options.to_h).to eq(exp)
  end
end

RSpec.describe Cargofile::Docker::Run do
  it "#initialize" do
    expect(Cargofile::Docker::Run.new).not_to be nil
  end

  it "#each" do
    ret = Cargofile::Docker::Run.new image: "fizz"
    expect(ret.to_a).to eq(%w[docker run fizz])
  end

  it "#cmd" do
    ret = Cargofile::Docker::Run.new image: "fizz"
    ret.cmd %w[echo hello]
    expect(ret.cmd).to eq(["echo", "hello"])
  end

  it "#to_s" do
    ret = Cargofile::Docker::Run.new(image: "fizz") do |r|
      r.options.rm true
      r.cmd %w[echo hello, world]
    end
    exp = "docker run --rm fizz echo hello, world"
    expect(ret.to_s).to eq(exp)
  end

  it "#with_defaults" do
    ret = Cargofile::Docker::Run.new do
      rm false
    end.with_defaults(rm: true)
    exp = {:rm=>[false]}
    expect(ret.options.to_h).to eq(exp)
  end
end

RSpec.describe Cargofile::Docker::Image do
  it "::parse(image)" do
    exp = "image"
    ret = Cargofile::Docker::Image.parse(exp).to_s
    expect(ret).to eq("#{exp}:latest")
  end

  it "::parse(username/image)" do
    exp = "username/image"
    ret = Cargofile::Docker::Image.parse(exp).to_s
    expect(ret).to eq("#{exp}:latest")
  end

  it "::parse(image:tag)" do
    exp = "image:tag"
    ret = Cargofile::Docker::Image.parse(exp).to_s
    expect(ret).to eq(exp)
  end

  it "::parse(username/image:tag)" do
    exp = "username/image:tag"
    ret = Cargofile::Docker::Image.parse(exp).to_s
    expect(ret).to eq(exp)
  end

  it "::parse(registry/username/image)" do
    exp = "registry:5000/username/image"
    ret = Cargofile::Docker::Image.parse(exp).to_s
    expect(ret).to eq("#{exp}:latest")
  end

  it "::parse(registry/username/image:tag)" do
    exp = "registry:5000/username/image:tag"
    ret = Cargofile::Docker::Image.parse(exp).to_s
    expect(ret).to eq(exp)
  end

  it "#each" do
    ret = Cargofile::Docker::Image.parse "registry/user/fizz:latest"
    exp = %w[registry user fizz latest]
    expect(ret.to_a).to eq(exp)
  end

  it "#family" do
    ret = Cargofile::Docker::Image.parse "registry/user/fizz:latest"
    exp = "registry/user/fizz"
    expect(ret.family).to eq(exp)
  end

  it "#to_s" do
    ret = Cargofile::Docker::Image.parse "registry/user/fizz:latest"
    exp = "registry/user/fizz:latest"
    expect(ret.to_s).to eq(exp)
  end
end
