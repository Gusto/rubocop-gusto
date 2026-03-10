# frozen_string_literal: true

require "thor"
require "rubocop/gusto/config_yml"
require "rubocop/gusto/init"

module RuboCop
  module Gusto
    # Thor-based CLI entry point for the rubocop-gusto gem (bin/rubocop-gusto).
    #
    # Commands:
    #   rubocop-gusto init              -bootstraps a project's .rubocop.yml with
    #                                     rubocop-gusto config (delegates to Init)
    #   rubocop-gusto sort [PATH]       -sorts cop entries in a .rubocop.yml file
    #                                     alphabetically in-place (uses ConfigYml)
    #
    # To add a new command, define a method with a +desc+ declaration, or register
    # a Thor::Group subclass for multi-step workflows.
    class Cli < Thor
      register(Init, "init", "init", "Initialize rubocop-gusto and update .rubocop.yml")

      desc "sort [RUBOCOP_YML_PATH]", "Sort the cops in a .rubocop.yml file (default: .rubocop.yml)"
      method_option :output, type: :string, default: nil, desc: "The path to the output file"
      def sort(rubocop_yml_path = ".rubocop.yml")
        say "Sorting #{rubocop_yml_path}..."
        output_path = options[:output] || rubocop_yml_path
        ConfigYml.load_file(rubocop_yml_path).sort!.write(output_path)
        say "Done! #{output_path} sorted."
      end
    end
  end
end
