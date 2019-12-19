RSpec.describe Rum::Manifest do
  before { allow_any_instance_of(Time).to receive(:to_i).and_return(1234567890) }
  before { allow_any_instance_of(Rum::Manifest).to receive :cp }
  before { allow_any_instance_of(Rum::Manifest).to receive :sh }
  before { allow_any_instance_of(Rum::Manifest).to receive :mkdir_p }
  before { allow(Dir).to receive(:[]).and_return %w[.docker/registry:5000 .docker/registry:5000/username .docker/registry:5000/username/name] }
  before { allow(File).to receive(:read).and_return "<digest>" }
  after  { Rake.application.clear }

  subject do
    Rum::Manifest.new("registry:5000/username/name").install do
      tag      "1.2.3"
      env      :FIZZ => "buzz"
      stage    :build
      stage    :test => :build
      artifact "pkg/fizz.zip" => :build
      artifact "buzz.zip" => :build
      shell    :build
      run      :jazz
      build    :fuzz
      default  "pkg/fizz.zip"

      run :razz, [:mtaz] do |t,args|
        image "#{t.name}/#{args[:mtaz]}"
      end

      build :mtaz, [:razz] do |t,args|
        tag "#{t.name}/#{args[:razz]}"
      end
    end.install
  end

  let(:stage) do
    -> (x) do
      <<~EOS.strip.gsub(/\n/,' ')
        docker build
        --build-arg FIZZ=buzz
        --iidfile .docker/registry:5000/username/name/1.2.3-#{x}@1234567890
        --tag registry:5000/username/name:1.2.3-#{x}
        --target #{x} .
      EOS
    end
  end

  describe "#build" do
    it "runs a Docker build command" do
      subject.application[:fuzz].invoke
      expect(subject).to have_received(:sh).with \
      "docker build --build-arg FIZZ=buzz ."
    end

    it "runs a Docker build command with a block" do
      subject.application[:mtaz].invoke("razz")
      expect(subject).to have_received(:sh).with \
      "docker build --build-arg FIZZ=buzz --tag mtaz/razz ."
    end
  end

  describe "#run" do
    it "runs a Docker run command" do
      subject.application[:jazz].invoke
      expect(subject).to have_received(:sh).with \
      "docker run --env FIZZ=buzz registry:5000/username/name:1.2.3"
    end

    it "runs a Docker run command with a block" do
      subject.application[:razz].invoke("mtaz")
      expect(subject).to have_received(:sh).with \
      "docker run --env FIZZ=buzz razz/mtaz"
    end
  end

  describe "#stage" do
    let(:path) { File.join(subject.home, *subject.image) }

    it "builds through `build` stage" do
      subject.application[:build].invoke
      expect(subject).to have_received(:sh).with(stage.call :build)
      expect(subject).to have_received(:cp).with("#{path}-build@1234567890", "#{path}-build")
    end

    it "builds through `test` stage" do
      subject.application[:test].invoke
      expect(subject).to have_received(:sh).with(stage.call :build)
      expect(subject).to have_received(:sh).with(stage.call :test)
      expect(subject).to have_received(:cp).with("#{path}-test@1234567890", "#{path}-test")
    end
  end

  describe "#artifact" do
    it "extracts the artifact" do
      cmd = <<~EOS.strip.gsub(/\n/,' ')
        docker run
        --env FIZZ=buzz
        --rm=true
        --entrypoint cat
        <digest>
        pkg/fizz.zip > pkg/fizz.zip
      EOS
      subject.application[:"pkg/fizz.zip"].invoke
      expect(subject).to have_received(:sh).with(stage.call :build)
      expect(subject).to have_received(:sh).with(cmd)
    end

    it "clobbers the artifact" do
      allow(File).to receive(:exist?).and_return(true)
      allow(subject).to receive(:rm_rf)
      subject.application[:clobber].invoke
      expect(subject).to have_received(:sh).twice.with(*%w[docker image rm --force <digest>])
      expect(subject).to have_received(:rm_rf).with(".docker/registry:5000/username/name/1.2.3-test")
      expect(subject).to have_received(:rm_rf).with(".docker/registry:5000/username/name/1.2.3-build")
      expect(subject).to have_received(:rm_rf).with("pkg/fizz.zip")
      expect(subject).to have_received(:rm_rf).with("pkg")
      expect(subject).to have_received(:rm_rf).with("buzz.zip")
      expect(subject).not_to have_received(:rm_rf).with(".")
    end
  end

  describe "#shell" do
    it "shells into the `build` stage" do
      cmd = <<~EOS.strip.gsub(/\n/,' ')
        docker run
        --env FIZZ=buzz
        --entrypoint /bin/sh
        --interactive=true
        --rm=true
        --tty=true
        <digest>
      EOS
      subject.application[:"shell:build"].invoke
      expect(subject).to have_received(:sh).with(stage.call :build)
      expect(subject).to have_received(:sh).with(cmd)
    end

    it "shells into the `test` stage" do
      cmd = <<~EOS.strip.gsub(/\n/,' ')
        docker run
        --env FIZZ=buzz
        --entrypoint /bin/sh
        --interactive=true
        --rm=true
        --tty=true
        <digest>
      EOS
      subject.application[:"shell:test"].invoke
      expect(subject).to have_received(:sh).with(stage.call :build)
      expect(subject).to have_received(:sh).with(stage.call :test)
      expect(subject).to have_received(:sh).with(cmd)
    end
  end

  describe "#install" do
    it "installs the clean command" do
      expect(subject.application[:clean]).not_to be nil
    end
  end

  describe "#install_default" do
    let(:path) { File.join(subject.home, *subject.image) }

    subject { Rum::Manifest.new("registry:5000/username/name").install }

    it "should install the default task" do
      subject.application[:default].invoke
      expect(subject).to have_received(:sh).with <<~EOS.strip
        docker build --iidfile .docker/registry:5000/username/name/latest@1234567890 --tag latest .
      EOS
      expect(subject).to have_received(:cp).with("#{path}@1234567890", path)
    end
  end

  describe "#build_options" do
    it "returns the default options" do
      expect(subject.send :build_options).to eq(build_arg: [{FIZZ: "buzz"}])
    end
  end

  describe "#run_options" do
    it "returns the default options" do
      expect(subject.send :run_options).to eq(env: [{FIZZ: "buzz"}])
    end
  end

  describe "#task_name" do
    after { ENV.delete "RUM_TASK_NAMES" }

    it "defaults to VERB_FIRST" do
      expect(subject.send :task_name, clean: "stage").to eq :"clean:stage"
    end

    it "uses to VERB_FIRST" do
      ENV["RUM_TASK_NAMES"] = "VERB_FIRST"
      expect(subject.send :task_name, clean: "stage").to eq :"clean:stage"
    end

    it "uses to STAGE_FIRST" do
      ENV["RUM_TASK_NAMES"] = "STAGE_FIRST"
      expect(subject.send :task_name, clean: "stage").to eq :"stage:clean"
    end
  end
end
