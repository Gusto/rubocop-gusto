# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags code that turns off TLS certificate verification or SSH host key verification.
      #
      # Only literal values under keys and setters that exist to control verification are flagged;
      # values chosen at runtime (config lookups, ternaries) are left alone. A bare `verify_mode` is
      # flagged only with the `OpenSSL::SSL::VERIFY_NONE` constant, since apps use that name for their own attributes.
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

        TLS_MODE_KEYS = %w(ssl_verify_mode openssl_verify_mode).to_set.freeze
        FALSE_DISABLES_KEYS = %w(verify_ssl ssl_verify ssl_verify_peer ssl_verifypeer verify_hostname).to_set.freeze
        HTTPARTY_FALSE_DISABLES_KEYS = %w(verify verify_peer).to_set.freeze

        # @!method openssl_ssl_namespace?(node)
        def_node_matcher :openssl_ssl_namespace?, <<~PATTERN
          (const (const {nil? cbase} :OpenSSL) :SSL)
        PATTERN

        # @!method qualified_verify_none?(node)
        def_node_matcher :qualified_verify_none?, <<~PATTERN
          (const #openssl_ssl_namespace? :VERIFY_NONE)
        PATTERN

        # @!method unqualified_verify_none?(node)
        def_node_matcher :unqualified_verify_none?, <<~PATTERN
          (const nil? :VERIFY_NONE)
        PATTERN

        # @!method none_literal?(node)
        def_node_matcher :none_literal?, <<~PATTERN
          {(int 0) (sym :none) (str "none")}
        PATTERN

        # @!method option_key(node)
        def_node_matcher :option_key, <<~PATTERN
          ({sym str} $_)
        PATTERN

        # @!method faraday_ssl_receiver?(node)
        def_node_matcher :faraday_ssl_receiver?, <<~PATTERN
          (call _ :ssl)
        PATTERN

        # @!method httparty_call?(node)
        def_node_matcher :httparty_call?, <<~PATTERN
          (send (const {nil? cbase} :HTTParty) _ ...)
        PATTERN

        # @!method net_ssh_start?(node)
        def_node_matcher :net_ssh_start?, <<~PATTERN
          (send (const (const {nil? cbase} :Net) {:SSH :SFTP :SCP}) :start ...)
        PATTERN

        # @!method disabling_host_key_verifier?(node)
        def_node_matcher :disabling_host_key_verifier?, <<~PATTERN
          {
            false
            (sym :never)
            (send (const (const (const (const {nil? cbase} :Net) :SSH) :Verifiers) {:Never :Null}) :new ...)
          }
        PATTERN

        def on_pair(node)
          key = option_key(node.key)&.to_s
          message = pair_message(node, key) if key
          add_offense(node, message:) if message
        end

        def on_send(node)
          add_offense(node, message: TLS_MSG) if tls_disabling_call?(node)
        end
        alias_method :on_csend, :on_send

        def on_casgn(node)
          return unless node.name == :VERIFY_PEER

          in_openssl_ssl = node.namespace ? openssl_ssl_namespace?(node.namespace) : inside_openssl_ssl_module?(node)
          add_offense(node, message: TLS_MSG) if in_openssl_ssl && verify_peer_override?(node.expression)
        end

        private

        def pair_message(node, key)
          value = node.value
          if tls_option_disabled?(key, value) || httparty_verify_disabled?(node, key) || faraday_ssl_verify_disabled?(node, key)
            TLS_MSG
          elsif host_key_verification_disabled?(node, key)
            SSH_MSG
          end
        end

        def tls_option_disabled?(key, value)
          if key == "verify_mode"
            verify_none_constant?(value)
          elsif TLS_MODE_KEYS.include?(key)
            verify_none_constant?(value) || none_literal?(value)
          elsif key == "ssl_verifyhost"
            value.int_type? && value.value.zero?
          else
            FALSE_DISABLES_KEYS.include?(key) && (value.false_type? || verify_none_constant?(value))
          end
        end

        def httparty_verify_disabled?(node, key)
          HTTPARTY_FALSE_DISABLES_KEYS.include?(key) && node.value.false_type? && httparty_call?(node.parent.parent)
        end

        def faraday_ssl_verify_disabled?(node, key)
          return false unless key == "verify" && node.value.false_type?

          options_owner = node.parent.parent
          options_owner&.pair_type? && option_key(options_owner.key)&.to_s == "ssl"
        end

        def host_key_verification_disabled?(node, key)
          return false unless disabling_host_key_verifier?(node.value)

          key == "verify_host_key" || (key == "paranoid" && net_ssh_start?(node.parent.parent))
        end

        def tls_disabling_call?(node)
          value = node.first_argument
          case node.method_name
          when :verify_mode= then value && (verify_none_constant?(value) || (faraday_ssl_receiver?(node.receiver) && none_literal?(value)))
          when :verify_hostname= then value&.false_type?
          when :verify= then faraday_ssl_receiver?(node.receiver) && value&.false_type?
          when :[]= then index_assignment_disables?(node)
          else verify_peer_const_set?(node)
          end
        end

        def index_assignment_disables?(node)
          key_node, value = *node.arguments
          key = option_key(key_node)&.to_s
          return false unless key && value

          tls_option_disabled?(key, value) || (key == "verify" && value.false_type? && faraday_ssl_receiver?(node.receiver))
        end

        def verify_peer_const_set?(node)
          name_node, value = *node.arguments
          return false unless option_key(name_node)&.to_s == "VERIFY_PEER" && value

          in_openssl_ssl = node.receiver ? openssl_ssl_namespace?(node.receiver) : inside_openssl_ssl_module?(node)
          in_openssl_ssl && verify_peer_override?(value)
        end

        def verify_peer_override?(value)
          return false unless value

          verify_none_constant?(value) || (value.int_type? && value.value.zero?)
        end

        def verify_none_constant?(value)
          qualified_verify_none?(value) || (unqualified_verify_none?(value) && inside_openssl_ssl_module?(value))
        end

        def inside_openssl_ssl_module?(node)
          node.each_ancestor(:module, :class).map { |scope| scope.identifier.const_name }.reverse.join("::") == "OpenSSL::SSL"
        end
      end
    end
  end
end
