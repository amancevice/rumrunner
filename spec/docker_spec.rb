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

RSpec.describe Cargofile::Docker::OptionCollection do
  it "#new" do
    ret = Cargofile::Docker::OptionCollection.new do |o|
      o.flag :value
      o.flag :key => :value
    end.instance_variable_get(:@options)
    exp = {:flag => [:value, {:key => :value}]}
    expect(ret).to eq(exp)
  end

  it "#each" do
    ret = Cargofile::Docker::OptionCollection.new do |o|
      o.flag :value
      o.flag :key => :value
    end.to_a
    exp = %w{--flag value --flag key=value}
    expect(ret).to eq(exp)
  end

  it "#method_missing" do
    ret = Cargofile::Docker::OptionCollection.new
    ret.fizz true
    expect(ret.instance_variable_get(:@options).keys).to eq([:fizz])
  end

  it "#clone" do
    opt1 = Cargofile::Docker::OptionCollection.new
    opt2 = opt1.clone
    opt2.flag :value
    expect(opt1.to_h).not_to eq(opt2.to_h)
  end

  it "#to_h" do
    ret = Cargofile::Docker::OptionCollection.new do |o|
      o.flag :value
      o.flag :key => :value
    end.to_h
    exp = {
      :flag => [
        :value,
        {:key => :value},
      ],
    }
    expect(ret).to eq(exp)
  end

  it "#to_s" do
    ret = Cargofile::Docker::OptionCollection.new do |o|
      o.flag :value
      o.flag :key => :value
    end.to_s
    exp = "--flag value --flag key=value"
    expect(ret).to eq(exp)
  end
end

RSpec.describe Cargofile::Docker::Build do
  it "#initialize" do
    expect(Cargofile::Docker::Build.new).not_to be nil
  end

  it "#each" do
    expect(Cargofile::Docker::Build.new.to_a).to eq(%w{docker build .})
  end

  it "#clone" do
    a = Cargofile::Docker::Build.new
    b = a.clone
    a.path "../."
    expect(a.to_a).not_to eq(b.to_a)
  end

  it "#to_h" do
    build = Cargofile::Docker::Build.new do |b|
      b.options.rm true
      b.options.label :FIZZ
    end
    exp = {path: nil, options: {rm: [true], label: [:FIZZ]}}
    expect(build.to_h).to eq(exp)
  end

  it "#to_s" do
    ret = Cargofile::Docker::Build.new do |b|
      b.options.build_arg :FIZZ => "buzz"
      b.options.build_arg :BUZZ
    end
    exp = "docker build --build-arg FIZZ=buzz --build-arg BUZZ ."
    expect(ret.to_s).to eq(exp)
  end
end

RSpec.describe Cargofile::Docker::Run do
  it "#initialize" do
    expect(Cargofile::Docker::Run.new).not_to be nil
  end

  it "#each" do
    ret = Cargofile::Docker::Run.new image: "fizz"
    expect(ret.to_a).to eq(%w{docker run fizz})
  end

  it "#clone" do
    a = Cargofile::Docker::Run.new image: "fizz"
    b = a.clone
    a.image "buzz"
    expect(a.to_a).not_to eq(b.to_a)
  end

  it "#to_h" do
    ret = Cargofile::Docker::Run.new do |r|
      r.options.rm true
      r.image "fizz"
      r.cmd *%w{echo hello, world}
    end
    exp = {cmd: %w{echo hello, world}, image: "fizz", options: {rm: [true]}}
    expect(ret.to_h).to eq(exp)
  end

  it "#to_s" do
    ret = Cargofile::Docker::Run.new(image: "fizz") do |r|
      r.options.rm true
      r.cmd *%w{echo hello, world}
    end
    exp = "docker run --rm fizz echo hello, world"
    expect(ret.to_s).to eq(exp)
  end
end

RSpec.describe Cargofile::Docker::Image do
  it "::parse(image)" do
    ret = Cargofile::Docker::Image.parse("image").to_h
    exp = {registry: nil, username: nil, name: "image", tag: nil}
  end

  it "::parse(username/image)" do
    ret = Cargofile::Docker::Image.parse("username/image").to_h
    exp = {registry: nil, username: "username", name: "image", tag: nil}
  end

  it "::parse(image:tag)" do
    ret = Cargofile::Docker::Image.parse("image:tag").to_h
    exp = {registry: nil, username: nil, name: "image", tag: "tag"}
  end

  it "::parse(username/image:tag)" do
    ret = Cargofile::Docker::Image.parse("username/image:tag").to_h
    exp = {registry: nil, username: "username", name: "image", tag: "tag"}
  end

  it "::parse(registry/username/image)" do
    ret = Cargofile::Docker::Image.parse("registry:5000/username/image").to_h
    exp = {registry: "registry:5000", username: "username", name: "image", tag: nil}
  end

  it "::parse(registry/username/image:tag)" do
    ret = Cargofile::Docker::Image.parse("registry:5000/username/image:tag").to_h
    exp = {registry: "registry:5000", username: "username", name: "image", tag: "tag"}
  end

  it "#clone" do
    a = Cargofile::Docker::Image.new name: "fizz"
    b = a.clone
    b.name "buzz"
    expect(a.to_h).not_to eq(b.to_h)
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

  it "#update" do
    ret = Cargofile::Docker::Image.parse "registry/user/fizz:latest"
    ret.update tag: "1.2.3"
    exp = "registry/user/fizz:1.2.3"
    expect(ret.to_s).to eq(exp)
  end
end
