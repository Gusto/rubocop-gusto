# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags code that turns off TLS certificate verification or SSH host key verification.
      #
      # Only literal values under keys and setters that exist to control verification are flagged;
      # values chosen at runtime (config lookups, ternaries) are left alone.
      #
      # @example
      #   # bad
      #   http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #   Redis.new(url: url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
      #   OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
      #   Faraday.new(url: url, ssl: { verify: false })
      #   HTTParty.get(url, verify: false)
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
        RESTRICT_ON_SEND = %i(verify_mode= verify_hostname= verify= []= const_set).freeze

        VERIFY_MODE_KEYS = %w(verify_mode ssl_verify_mode openssl_verify_mode).to_set.freeze
        FALSE_DISABLES_KEYS = %w(verify_ssl ssl_verify ssl_verify_peer ssl_verifypeer verify_hostname).to_set.freeze
        HTTPARTY_FALSE_DISABLES_KEYS = %i(verify verify_peer).to_set.freeze

        # @!method openssl_ssl_namespace?(node)
        def_node_matcher :openssl_ssl_namespace?, <<~PATTERN
          (const (const {nil? cbase} :OpenSSL) :SSL)
        PATTERN

        # @!method verify_none_value?(node)
        def_node_matcher :verify_none_value?, <<~PATTERN
          {(const #openssl_ssl_namespace? :VERIFY_NONE) (int 0) (sym :none) (str "none")}
        PATTERN

        # @!method option_key(node)
        def_node_matcher :option_key, <<~PATTERN
          {(sym $_) (str $_)}
        PATTERN

        # @!method faraday_ssl_receiver?(node)
        def_node_matcher :faraday_ssl_receiver?, <<~PATTERN
          (call _ :ssl)
        PATTERN

        # @!method faraday_ssl_verify_disabled(node)
        def_node_matcher :faraday_ssl_verify_disabled, <<~PATTERN
          (pair (sym :ssl) (hash <$(pair (sym :verify) false) ...>))
        PATTERN

        # @!method httparty_call?(node)
        def_node_matcher :httparty_call?, <<~PATTERN
          (send (const {nil? cbase} :HTTParty) _ ...)
        PATTERN

        # @!method net_ssh_start?(node)
        def_node_matcher :net_ssh_start?, <<~PATTERN
          (send (const (const {nil? cbase} :Net) {:SSH :SFTP :SCP}) :start ...)
        PATTERN

        # @!method host_key_verification_disabled?(node)
        def_node_matcher :host_key_verification_disabled?, <<~PATTERN
          (pair (sym :verify_host_key) {(sym :never) false})
        PATTERN

        # @!method paranoid_disabled?(node)
        def_node_matcher :paranoid_disabled?, <<~PATTERN
          (pair (sym :paranoid) false)
        PATTERN

        # @!method verify_peer_const_set?(node)
        def_node_matcher :verify_peer_const_set?, <<~PATTERN
          (call #openssl_ssl_namespace? :const_set {(sym :VERIFY_PEER) (str "VERIFY_PEER")} (const #openssl_ssl_namespace? :VERIFY_NONE))
        PATTERN

        def on_pair(node)
          faraday_ssl_verify_disabled(node) { |verify_pair| add_offense(verify_pair, message: TLS_MSG) }

          if tls_option_disabled?(node.key, node.value) || httparty_verify_disabled?(node)
            add_offense(node, message: TLS_MSG)
          elsif host_key_verification_disabled?(node) || net_ssh_paranoid_disabled?(node)
            add_offense(node, message: SSH_MSG)
          end
        end

        def on_send(node)
          add_offense(node, message: TLS_MSG) if tls_disabling_call?(node)
        end
        alias_method :on_csend, :on_send

        def on_casgn(node)
          return unless node.name == :VERIFY_PEER && openssl_ssl_namespace?(node.namespace)
          return unless verify_none_value?(node.expression) && node.expression.const_type?

          add_offense(node, message: TLS_MSG)
        end

        private

        def tls_disabling_call?(node)
          case node.method_name
          when :verify_mode= then verify_none_value?(node.first_argument)
          when :verify_hostname= then node.first_argument.false_type?
          when :verify= then faraday_ssl_receiver?(node.receiver) && node.first_argument.false_type?
          when :[]= then index_assignment_disables?(node)
          else verify_peer_const_set?(node)
          end
        end

        def index_assignment_disables?(node)
          key, value = *node.arguments
          return false unless value

          tls_option_disabled?(key, value) || (faraday_ssl_receiver?(node.receiver) && option_key(key) == :verify && value.false_type?)
        end

        def tls_option_disabled?(key_node, value_node)
          key = option_key(key_node)&.to_s
          return verify_none_value?(value_node) if VERIFY_MODE_KEYS.include?(key)
          return value_node.int_type? && value_node.value.zero? if key == "ssl_verifyhost"

          FALSE_DISABLES_KEYS.include?(key) && value_node.false_type?
        end

        def httparty_verify_disabled?(node)
          HTTPARTY_FALSE_DISABLES_KEYS.include?(option_key(node.key)) && node.value.false_type? && httparty_call?(node.parent.parent)
        end

        def net_ssh_paranoid_disabled?(node)
          paranoid_disabled?(node) && net_ssh_start?(node.parent.parent)
        end
      end
    end
  end
end
