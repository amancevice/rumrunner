require "bundler/setup"
require "rake/clean"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new :spec

task :default => :spec

namespace :gem do
  require "bundler/gem_tasks"
end

namespace :cargo do
  load "Cargofile" unless ENV["RAKE_ENV"] == "test"
end
