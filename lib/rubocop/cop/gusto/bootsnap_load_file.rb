# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Do not use Bootsnap to load files. Use `require` instead.
      class BootsnapLoadFile < Base
        PROHIBITED_CONSTANTS = Set[:YAML, :JSON].freeze
        RESTRICT_ON_SEND = %i(load).freeze

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
        alias_method :on_numblock, :on_block

        def on_send(node)
          yaml_or_json_load(node) do |constant_node|
            on_load(node, constant_node)
          end
        end

        private

        # Look for File.read as the first argument
        def on_load(node, constant_node)
          return unless node.first_argument

          file_read(node.first_argument) do |read_file_node|
            add_offense(node, message: "Use #{constant_node.source}.load_file(#{read_file_node.source}) to improve load time with bootsnap")
          end
        end
      end
    end
  end
end
