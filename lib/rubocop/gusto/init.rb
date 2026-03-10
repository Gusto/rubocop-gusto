# frozen_string_literal: true

require "pathname"
require "yaml"
require "rubocop/gusto/config_yml"

module RuboCop
  module Gusto
    # Thor::Group that bootstraps rubocop-gusto in a new project (rubocop-gusto init).
    #
    # Runs two steps in order:
    #   1. +add_dependencies+ — adds rubocop-rails (Rails apps only) and binstubs rubocop
    #   2. +copy_config_files+ — creates or updates .rubocop.yml to inherit from
    #      rubocop-gusto's config files, adds required plugins, sorts the result,
    #      and creates an empty .rubocop_todo.yml if one doesn't exist
    #
    # Rails detection is based on the presence of config/application.rb.
    # rubocop-rails is intentionally not a gem dependency so rubocop-gusto can be
    # used in non-Rails projects; it is added to the project's Gemfile on demand.
    # Templates live in lib/rubocop/gusto/templates/.
    # The target .rubocop.yml path is configurable via --rubocop_yml.
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
