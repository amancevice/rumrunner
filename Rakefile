require "rspec/core/rake_task"

RSpec::Core::RakeTask.new :spec

task :default => :spec

namespace :gem do
  require "bundler/gem_tasks"

  task :push do
    sh "gem push pkg/#{Bundler::GemHelper.gemspec.full_name}.gem"
  end
end
