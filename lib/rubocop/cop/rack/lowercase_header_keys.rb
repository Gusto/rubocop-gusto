# frozen_string_literal: true

module RuboCop
  module Cop
    module Rack
      # Detects HTTP response headers with uppercase characters.
      # HTTP response header keys should be lowercase for compatibility
      # with Rack 3, HTTP/2, and modern web standards.
      #
      # Rack 3 no longer normalizes header keys, so mixed-case keys like
      # 'Content-Type' will be stored as-is and won't match lowercase
      # lookups. All response header keys must be lowercase.
      #
      # @example
      #   # bad
      #   headers['Content-Type'] = 'application/json'
      #   response.headers['Location'] = '/redirect'
      #   response.set_header('X-Custom', 'value')
      #   response.headers['Content-Security-Policy'] += policy
      #
      #   # good
      #   headers['content-type'] = 'application/json'
      #   response.headers['location'] = '/redirect'
      #   response.set_header('x-custom', 'value')
      #   response.headers['content-security-policy'] += policy
      #
      class LowercaseHeaderKeys < Base
        extend AutoCorrector

        MSG = "HTTP response header keys should be lowercase. Use `%<downcased>s` instead of `%<original>s`."
        RESTRICT_ON_SEND = %i([]= [] set_header get_header delete_header has_header?).freeze

        # @!method response_header_method?(node)
        def_node_matcher :response_header_method?, <<~PATTERN
          (send
            {
              (send nil? :response)
              (lvar :response)
              (self)
            }
            {:set_header :get_header :delete_header :has_header?}
            (str _)
            ...
          )
        PATTERN

        def on_send(node)
          if node.method?(:[]=) || node.method?(:[])
            check_bracket_access(node)
          elsif response_header_method?(node)
            check_header_method(node)
          end
        end
        alias_method :on_csend, :on_send

        # Handle compound assignment: headers['Key'] += val
        # Ruby parses this as an op_asgn node, not a []= send
        def on_op_asgn(node)
          lhs = node.children[0]
          return unless lhs.send_type? && lhs.method?(:[])

          receiver = lhs.receiver
          return unless receiver&.send_type? && response_headers_receiver?(receiver)

          key_node = lhs.first_argument
          return unless key_node&.str_type?

          check_key(key_node)
        end

        private

        def check_bracket_access(node)
          receiver = node.receiver
          return unless receiver&.send_type? && response_headers_receiver?(receiver)

          key_node = node.first_argument
          return unless key_node&.str_type?

          check_key(key_node)
        end

        def check_header_method(node)
          key_node = node.first_argument
          check_key(key_node)
        end

        def check_key(key_node)
          key_value = key_node.value
          return if key_value.empty?
          return if key_value == key_value.downcase

          add_offense_for_header(key_node, key_value)
        end

        # Matches headers receivers that are response-related:
        #   headers (bare method call in controller)
        #   response.headers
        #   self.headers
        # Does NOT match:
        #   conn.headers, request.headers, client.headers, etc.
        def response_headers_receiver?(receiver)
          return false unless receiver.method?(:headers)

          inner = receiver.receiver
          if inner.nil?
            # Bare `headers` method call (Rails controller helper)
            true
          elsif inner.self_type?
            # `self.headers`
            true
          elsif inner.send_type? && inner.receiver.nil? && inner.method?(:response)
            # `response.headers`
            true
          elsif inner.lvar_type? && inner.children.first == :response
            # `response.headers` where response is a local var
            true
          else
            false
          end
        end

        def add_offense_for_header(node, key_value)
          downcased = key_value.downcase
          message = format(MSG, downcased: downcased, original: key_value)

          add_offense(node, message: message) do |corrector|
            corrector.replace(node, "'#{downcased}'")
          end
        end
      end
    end
  end
end
