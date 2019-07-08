RSpec.describe "#cargo" do
  it "installs the tasks" do
    cargo :fizz => :dir do |c|
      c.tag "fizz"
      c.stage :buzz
      c.stage :jazz
      c.stage :fuzz do |s|
        s.artifact "tmp/foo" do |a|
          a.workdir "/tmp/"
        end
      end
    end
    expect(CLEAN).to eq(%w{dir dir/fizz-buzz dir/fizz-jazz dir/fizz-fuzz})
  end
end
