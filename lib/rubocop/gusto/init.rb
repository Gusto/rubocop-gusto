# frozen_string_literal: true

require "pathname"
require "yaml"
require "rubocop/gusto/config_yml"

module RuboCop
  module Gusto
    class Init < Thor::Group
      include Thor::Actions

      PLUGINS = %w(rubocop-gusto rubocop-rspec rubocop-performance rubocop-rake rubocop-rails).freeze
      SIDEKIQ_GEM_PATTERN = /\A\s*gem\s+['"]sidekiq['"]/
      SIDEKIQ_LOCKFILE_PATTERN = /\A\s+sidekiq\s+\(/

      class_option :rubocop_yml, type: :string, default: ".rubocop.yml"

      def self.source_root
        File.expand_path("templates", __dir__)
      end

      def add_dependencies
        if rails?
          # we don't want rubocop-rails to be a dependency of the gem so that we can use this in non-rails gems
          run "bundle show rubocop-rails >/dev/null || bundle add rubocop-rails --group development", capture: true
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
        config.add_plugin(rails? ? PLUGINS : PLUGINS - %w(rubocop-rails))

        config.sort!
        config.write(options[:rubocop_yml])
        say_status "update", options[:rubocop_yml]

        create_file(".rubocop_todo.yml", skip: true)
      end

      private

      def inherit_gem_configs
        configs = ["config/default.yml"]
        configs << "config/rails.yml" if rails?
        configs << "config/sidekiq.yml" if sidekiq?
        configs
      end

      def rails?
        File.exist?("config/application.rb")
      end

      def sidekiq?
        gem_referenced?("Gemfile", SIDEKIQ_GEM_PATTERN) ||
          gem_referenced?("Gemfile.lock", SIDEKIQ_LOCKFILE_PATTERN)
      end

      def gem_referenced?(path, pattern)
        File.exist?(path) && File.foreach(path).any? { |line| line.match?(pattern) }
      end
    end
  end
end
