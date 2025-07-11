# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/gusto/cli'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc 'Update the .rubocop.yml template that is installed by rubocop-gusto init'
task :update_template do
  template_path = File.expand_path('lib/rubocop/gusto/templates/rubocop.yml', __dir__)
  RuboCop::Gusto::Cli.start(['init', '--rubocop-yml', template_path])
end
