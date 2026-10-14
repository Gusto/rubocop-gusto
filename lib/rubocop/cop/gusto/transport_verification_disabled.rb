# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags code that turns off TLS certificate verification or SSH host key verification.
      #
      # Only literal values are flagged; values chosen at runtime (config lookups, ternaries) are left alone.
      #
      # @example
      #   # bad
      #   http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #   Redis.new(url: url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
      #   Faraday.new(url: url, ssl: { verify: false })
      #   conn.ssl.verify = false
      #   RestClient::Request.execute(url: url, verify_ssl: false)
      #   Net::SFTP.start(host, user, verify_host_key: :never)
      #
      #   # good
      #   http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      #   Faraday.new(url: url, ssl: { ca_file: ca_file })
      #   Net::SFTP.start(host, user, verify_host_key: :always)
      class TransportVerificationDisabled < Base
        TLS_MSG = "Do not disable TLS certificate verification."
        SSH_MSG = "Do not disable SSH host key verification."
        RESTRICT_ON_SEND = %i(verify_mode= verify= const_set).freeze

        TLS_VERIFICATION_KEYS = %i(verify_ssl ssl_verify ssl_verify_peer ssl_verifypeer).to_set.freeze

        # @!method verify_none?(node)
        def_node_matcher :verify_none?, <<~PATTERN
          (const (const (const {nil? cbase} :OpenSSL) :SSL) :VERIFY_NONE)
        PATTERN

        # @!method openssl_ssl_namespace?(node)
        def_node_matcher :openssl_ssl_namespace?, <<~PATTERN
          (const (const {nil? cbase} :OpenSSL) :SSL)
        PATTERN

        # @!method disabled_tls_option?(node)
        def_node_matcher :disabled_tls_option?, <<~PATTERN
          (pair (sym %TLS_VERIFICATION_KEYS) false)
        PATTERN

        # @!method faraday_ssl_verify_false?(node)
        def_node_matcher :faraday_ssl_verify_false?, <<~PATTERN
          (pair (sym :verify) false)
        PATTERN

        # @!method ssl_options_hash?(node)
        def_node_matcher :ssl_options_hash?, <<~PATTERN
          (pair (sym :ssl) hash)
        PATTERN

        # @!method disabled_host_key_verification?(node)
        def_node_matcher :disabled_host_key_verification?, <<~PATTERN
          (pair (sym :verify_host_key) {(sym :never) false})
        PATTERN

        # @!method faraday_ssl_setter_false?(node)
        def_node_matcher :faraday_ssl_setter_false?, <<~PATTERN
          (call (call _ :ssl) :verify= false)
        PATTERN

        # @!method verify_peer_const_set(node)
        def_node_matcher :verify_peer_const_set, <<~PATTERN
          (call _ :const_set (sym :VERIFY_PEER) $#verify_none?)
        PATTERN

        def on_pair(node)
          if verify_none?(node.value)
            add_offense(node.value, message: TLS_MSG)
          elsif disabled_tls_option?(node) || faraday_ssl_option_disabled?(node)
            add_offense(node, message: TLS_MSG)
          elsif disabled_host_key_verification?(node)
            add_offense(node, message: SSH_MSG)
          end
        end

        def on_send(node)
          if node.method?(:verify_mode=)
            value = node.first_argument
            add_offense(value, message: TLS_MSG) if verify_none?(value)
          elsif faraday_ssl_setter_false?(node)
            add_offense(node, message: TLS_MSG)
          else
            verify_peer_const_set(node) { |value| add_offense(value, message: TLS_MSG) }
          end
        end
        alias_method :on_csend, :on_send

        def on_casgn(node)
          return unless node.name == :VERIFY_PEER && openssl_ssl_namespace?(node.namespace)
          return unless verify_none?(node.expression)

          add_offense(node.expression, message: TLS_MSG)
        end

        private

        def faraday_ssl_option_disabled?(node)
          return false unless faraday_ssl_verify_false?(node)

          ssl_options_hash?(node.parent.parent)
        end
      end
    end
  end
end
