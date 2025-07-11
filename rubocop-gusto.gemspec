# frozen_string_literal: true

require_relative 'lib/rubocop/gusto/version'

Gem::Specification.new do |spec|
  spec.name          = 'rubocop-gusto'
  spec.version       = RuboCop::Gusto::VERSION
  spec.authors       = ['Gusto Engineering']
  spec.email         = ['gusto-opensource-buildkite@gusto.com']

  spec.summary       = 'A gem for sharing gusto rubocop rules'
  spec.homepage      = 'https://github.com/gusto/rubocop-gusto'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.2'

  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = 'https://rubygems.org'
    spec.metadata['default_lint_roller_plugin'] = 'RuboCop::Gusto::Plugin'
  else
    raise('RubyGems 2.0 or newer is required to protect against public gem pushes.')
  end

  spec.files = Dir['{lib,exe,config}/**/*', 'README.md', 'CHANGELOG.md', 'LICENSE']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r(\Aexe/)) { |f| File.basename(f) }

  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'lint_roller'
  spec.add_dependency 'rubocop'
  spec.add_dependency 'rubocop-performance'
  spec.add_dependency 'rubocop-rails'
  spec.add_dependency 'rubocop-rake'
  spec.add_dependency 'rubocop-rspec'
  spec.add_dependency 'thor'
end
