# frozen_string_literal: true

require "pathname"
require "yaml"
require "rubocop/gusto/config_yml"

module RuboCop
  module Gusto
    class Init < Thor::Group
      include Thor::Actions

      PLUGINS = %w(rubocop-gusto rubocop-rspec rubocop-performance rubocop-rake rubocop-rails).freeze

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

        if rails?
          config.add_inherit_gem("rubocop-gusto", "config/default.yml", "config/rails.yml")
          config.add_plugin(PLUGINS)
        else
          config.add_inherit_gem("rubocop-gusto", "config/default.yml")
          config.add_plugin(PLUGINS - %w(rubocop-rails))
        end

        config.sort!
        config.write(options[:rubocop_yml])
        say_status "update", options[:rubocop_yml]

        create_file(".rubocop_todo.yml", skip: true)
      end

      private

      def rails?
        File.exist?("config/application.rb")
      end
    end
  end
end
