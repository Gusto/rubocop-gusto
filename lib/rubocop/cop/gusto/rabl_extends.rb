# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Disallows the use of `extends` in Rabl templates due to poor caching performance.
      # Inline the templating to generate your JSON instead.
      #
      # @example
      #   # bad
      #   extends 'path/to/template'
      #
      #   # bad - but not covered by this rule
      #   partial 'path/to/template'
      #
      #   # good - inline your templating
      #   node 'some_node'
      #   attributes :foo, :bar
      #   child(:baz) { attributes :qux }
      #
      class RablExtends < Base
        MSG = "Avoid using Rabl extends as it has poor caching performance. Inline your JSON instead."
        RABL_EXTENSION = ".rabl"
        RESTRICT_ON_SEND = %i(extends).freeze

        # @!method rabl_extends?(node)
        def_node_matcher :rabl_extends?, <<~PATTERN
          (send nil? :extends (str _) ...)
        PATTERN

        def on_send(node)
          return unless rabl_extends?(node)

          add_offense(node)
        end

        def relevant_file?(file)
          file.end_with?(RABL_EXTENSION)
        end
      end
    end
  end
end
