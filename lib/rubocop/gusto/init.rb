# frozen_string_literal: true

require "pathname"
require "yaml"
require "rubocop/gusto/config_yml"

module RuboCop
  module Gusto
    class Init < Thor::Group
      include Thor::Actions

      PLUGINS = %w(rubocop-gusto rubocop-rspec rubocop-performance rubocop-rake).freeze
      GRAPHQL_GEM_PATTERN = /\A\s*gem\s+['"]graphql['"]/
      GRAPHQL_LOCKFILE_PATTERN = /\A\s+graphql\s+\(/
      SIDEKIQ_GEM_PATTERN = /\A\s*gem\s+['"]sidekiq['"]/
      SIDEKIQ_LOCKFILE_PATTERN = /\A\s+sidekiq\s+\(/
      # Matches the whole sorbet family: sorbet, sorbet-runtime, sorbet-static-and-runtime
      SORBET_GEM_PATTERN = /\A\s*gem\s+['"]sorbet(-[\w-]+)?['"]/
      SORBET_LOCKFILE_PATTERN = /\A\s+sorbet(-[\w-]+)?\s+\(/

      class_option :rubocop_yml, type: :string, default: ".rubocop.yml"

      def self.source_root
        File.expand_path("templates", __dir__)
      end

      def add_dependencies
        detected_optional_plugins.each do |plugin|
          run "bundle show #{plugin} >/dev/null || bundle add #{plugin} --group development", capture: true
        end

        run "bundle binstub rubocop", capture: true
      end

      def copy_config_files
        config = ConfigYml.load_file(options[:rubocop_yml])

        if config.empty?
          template "rubocop.yml", options[:rubocop_yml]
          config = ConfigYml.load_file(options[:rubocop_yml])
        end

        config.add_inherit_gem("rubocop-gusto", *inherit_gem_configs)
        config.add_plugin(PLUGINS + detected_optional_plugins)

        config.sort!
        config.write(options[:rubocop_yml])
        say_status "update", options[:rubocop_yml]

        create_file(".rubocop_todo.yml", skip: true)
      end

      private

      # Plugins for a tool the project may not use. They are not gemspec dependencies, which is
      # what lets rubocop-gusto be used from a plain gem with no Rails or GraphQL in sight, so
      # `init` adds each one to the project's Gemfile as well as its `plugins:` list.
      def detected_optional_plugins
        plugins = []
        plugins << "rubocop-graphql" if graphql?
        plugins << "rubocop-rails" if rails?
        plugins
      end

      def inherit_gem_configs
        configs = ["config/default.yml"]
        configs << "config/graphql.yml" if graphql?
        configs << "config/rails.yml" if rails?
        configs << "config/sidekiq.yml" if sidekiq?
        configs << "config/sorbet.yml" if sorbet?
        configs
      end

      def graphql?
        gem_referenced?("Gemfile", GRAPHQL_GEM_PATTERN) ||
          gem_referenced?("Gemfile.lock", GRAPHQL_LOCKFILE_PATTERN)
      end

      def rails?
        File.exist?("config/application.rb")
      end

      def sidekiq?
        gem_referenced?("Gemfile", SIDEKIQ_GEM_PATTERN) ||
          gem_referenced?("Gemfile.lock", SIDEKIQ_LOCKFILE_PATTERN)
      end

      def sorbet?
        gem_referenced?("Gemfile", SORBET_GEM_PATTERN) ||
          gem_referenced?("Gemfile.lock", SORBET_LOCKFILE_PATTERN)
      end

      def gem_referenced?(path, pattern)
        File.exist?(path) && File.foreach(path).any? { |line| line.match?(pattern) }
      end
    end
  end
end
