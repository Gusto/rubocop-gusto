# frozen_string_literal: true

module RuboCop
  module Cop
    module Rack
      # Detects HTTP response headers with uppercase characters.
      # HTTP response header keys should be lowercase for consistency
      # and compatibility with HTTP/2 and modern web standards.
      #
      # @example
      #   # bad
      #   headers['Content-Type'] = 'application/json'
      #   response.headers['Location'] = '/redirect'
      #
      #   # good
      #   headers['content-type'] = 'application/json'
      #   response.headers['location'] = '/redirect'
      #
      class LowercaseHeaderKeys < Base
        extend AutoCorrector

        MSG = 'HTTP response header keys should be lowercase. Use `%{downcased}` instead of `%{original}`.'
        RESTRICT_ON_SEND = %i([]=).freeze

        # Known HTTP headers (case-insensitive check)
        KNOWN_HEADERS = Set.new(
          %w(
            Accept Accept-Charset Accept-Encoding Accept-Language Accept-Ranges
            Access-Control-Allow-Credentials Access-Control-Allow-Headers
            Access-Control-Allow-Methods Access-Control-Allow-Origin
            Access-Control-Allow-Private-Network Access-Control-Expose-Headers
            Access-Control-Max-Age Access-Control-Request-Headers
            Access-Control-Request-Method Age Allow Authorization
            Cache-Control Connection Content-Disposition Content-Encoding
            Content-Language Content-Length Content-Location Content-Range
            Content-Security-Policy Content-Security-Policy-Report-Only
            Content-Type Cookie Date ETag Expect
            Expires Forwarded From Host If-Match If-Modified-Since
            If-None-Match If-Range If-Unmodified-Since Last-Modified
            Link Location Max-Forwards Origin Pragma Proxy-Authenticate
            Proxy-Authorization Range Referer Referrer-Policy Retry-After
            Server Set-Cookie SOAPAction Strict-Transport-Security TE Trailer
            Transfer-Encoding Upgrade User-Agent Vary Via Warning
            WWW-Authenticate X-Content-Type-Options X-Frame-Options
            X-XSS-Protection X-Forwarded-For X-Forwarded-Host X-Forwarded-Proto
            X-Real-IP X-Request-ID X-Request-Start X-Requested-With
          ).map(&:downcase)
        ).freeze

        def on_send(node)
          return unless headers_assignment?(node)

          key_node = node.first_argument
          return unless key_node.str_type?

          key_value = key_node.value
          return unless uppercase_known_header?(key_value)

          add_offense_for_header(key_node, key_value)
        end

        private

        def uppercase_known_header?(key)
          return false if key.empty?
          return false if key == key.downcase

          KNOWN_HEADERS.include?(key.downcase)
        end

        # Matches:
        #   headers['...'] = value (bare method call in controller)
        #   response.headers['...'] = value
        # Does NOT match:
        #   conn.headers, request.headers, client.headers, etc.
        def headers_assignment?(node)
          receiver = node.receiver
          # RESTRICT_ON_SEND ensures we only see []=, which always has a receiver
          return false unless receiver.send_type?

          headers_method_receiver?(receiver)
        end

        def headers_method_receiver?(receiver)
          return false unless receiver.method?(:headers)

          inner = receiver.receiver
          if inner.nil?
            # Bare `headers` method call (Rails controller helper)
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
