require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc 'Run RuboCop'
task :rubocop do
  system 'rubocop'
end

desc 'Run all checks (tests and rubocop)'
task check: [:spec, :rubocop] 