# frozen_string_literal: true

require 'thor'
require 'rubocop/gusto/config_yml'
require 'rubocop/gusto/init'

module RuboCop
  module Gusto
    class Cli < Thor
      register(Init, 'init', 'init', 'Initialize rubocop-gusto and update .rubocop.yml')

      desc 'sort [RUBOCOP_YML_PATH]', 'Sort the cops in a .rubocop.yml file (default: .rubocop.yml)'
      method_option :output, type: :string, default: nil, desc: 'The path to the output file'
      def sort(rubocop_yml_path = '.rubocop.yml')
        say "Sorting #{rubocop_yml_path}..."
        output_path = options[:output] || rubocop_yml_path
        ConfigYml.load_file(rubocop_yml_path).sort!.write(output_path)
        say "Done! #{output_path} sorted."
      end
    end
  end
end
