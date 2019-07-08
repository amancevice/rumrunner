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
    a.path = "../."
    expect(a.to_a).not_to eq(b.to_a)
  end

  it "#to_h" do
    build = Cargofile::Docker::Build.new.rm.label(:FIZZ)
    expect(build.to_h).to eq({path: nil, options: {rm: [], label: [:FIZZ]}})
  end

  it "#to_s" do
    ret = Cargofile::Docker::Build.new
    ret.build_arg :FIZZ => "buzz"
    ret.build_arg :BUZZ
    exp = "docker build --build-arg FIZZ=buzz --build-arg BUZZ ."
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
    b.name = "buzz"
    expect(a.to_h).not_to eq(b.to_h)
  end

  it "#tag" do
    ret = Cargofile::Docker::Image.new name: "fizz"
    ret.tag "buzz"
    expect(ret.to_s).to eq("fizz:buzz")
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
    a.image = "buzz"
    expect(a.to_a).not_to eq(b.to_a)
  end

  it "#to_h" do
    ret = Cargofile::Docker::Run.new
    ret.cmd *%w{echo hello, world}
    ret.rm
    ret.image "fizz"
    expect(ret.to_h).to eq({cmd: %w{echo hello, world}, image: "fizz", options: {rm: []}})
  end

  it "#to_s" do
    ret = Cargofile::Docker::Run.new image: "fizz"
    ret.rm
    ret.cmd %w{echo hello, world}
    exp = "docker run --rm fizz echo hello, world"
    expect(ret.to_s).to eq(exp)
  end
end
