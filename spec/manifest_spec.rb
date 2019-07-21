RSpec.describe Rum::Manifest do
  it "defines a whole bunch of tasks" do
    manifest = Rum::Manifest.new(:name => :"registry:5000/username/name") do
      tag      "1.2.3"
      default  :build
      stage    :build
      artifact "fizz" => :build

      shell :build

      run   :jazz
      build :fuzz
    end
    manifest.install

    ret = Hash[Rake::Task.tasks.collect{|x| [x.name, x.class] }]
    exp = {
      ".docker"                                         => Rake::FileCreationTask,
      ".docker/registry:5000"                           => Rake::FileCreationTask,
      ".docker/registry:5000/username"                  => Rake::FileCreationTask,
      ".docker/registry:5000/username/name:1.2.3-build" => Rake::FileTask,
      "build"                                           => Rake::Task,
      "build:clean"                                     => Rake::Task,
      "build:shell"                                     => Rake::Task,
      "clean"                                           => Rake::Task,
      "clobber"                                         => Rake::Task,
      "default"                                         => Rake::Task,
      "fizz"                                            => Rake::FileTask,
      "fuzz"                                            => Rake::Task,
      "jazz"                                            => Rake::Task,
    }
    expect(ret).to eq(exp)
  end
end
