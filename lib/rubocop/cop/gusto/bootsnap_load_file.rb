# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for calls to `YAML.load` or `JSON.load` that receive a
      # `File.read` argument, and for `YAML.load` or `JSON.load` called
      # inside a `File.open` block. These patterns bypass Bootsnap's file
      # caching. Use `YAML.load_file` or `JSON.load_file` instead so that
      # Bootsnap can cache the parsed result and speed up boot time.
      #
      # @example
      #   # bad
      #   YAML.load(File.read('config/settings.yml'))
      #   JSON.load(File.read('data/records.json'))
      #
      #   File.open('config/settings.yml') do |f|
      #     YAML.load(f)
      #   end
      #
      #   # good
      #   YAML.load_file('config/settings.yml')
      #   JSON.load_file('data/records.json')
      #
      class BootsnapLoadFile < Base
        PROHIBITED_CONSTANTS = Set[:YAML, :JSON].freeze
        RESTRICT_ON_SEND = %i[load].freeze

        # @!method yaml_or_json_load(node)
        def_node_matcher :yaml_or_json_load, "(send $(const nil? PROHIBITED_CONSTANTS) :load ...)"

        # @!method file_read(node)
        def_node_matcher :file_read, "(send (const nil? :File) :read $_)"

        # @!method load_inside_file_open(node)
        def_node_matcher :load_inside_file_open, <<~PATTERN
          (block
            (send
              (const nil? :File) :open
              $(str _))
            (args
              (arg _file))
            (send
              $(const nil? :YAML) :load
              (lvar _file))
          )
        PATTERN

        def on_block(node)
          load_inside_file_open(node) do |file_path_node, constant_node|
            add_offense(node, message: "Use #{constant_node.source}.load_file(#{file_path_node.source}) to improve load time with bootsnap")
          end
        end
        alias_method :on_itblock, :on_block
        alias_method :on_numblock, :on_block

        def on_send(node)
          yaml_or_json_load(node) do |constant_node|
            on_load(node, constant_node)
          end
        end

        # Look for File.read as the first argument
        private def on_load(node, constant_node)
          return unless node.first_argument

          file_read(node.first_argument) do |read_file_node|
            add_offense(node, message: "Use #{constant_node.source}.load_file(#{read_file_node.source}) to improve load time with bootsnap")
          end
        end
      end
    end
  end
end
