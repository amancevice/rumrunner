require "gems"
require "rake/clean"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new :spec

task :default => :spec

namespace :gem do
  require "bundler/gem_tasks"

  gem = Gem::Specification::load("rumfile.gemspec")

  desc "Push #{gem.full_name}.gem to rubygems.org"
  task :publish do
    Gems.key = ENV["RUBYGEMS_API_KEY"]
    $stderr.puts Gems.push File.new "pkg/#{gem.full_name}.gem"
  end
end
