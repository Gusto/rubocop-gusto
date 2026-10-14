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
        TLS_MODE_KEYS = %w(ssl_verify_mode openssl_verify_mode).to_set.freeze
        FALSE_DISABLES_KEYS = %w(
          verify_ssl ssl_verify ssl_verify_peer ssl_verifypeer verify_hostname ssl_verify_certificate ssl_verify_hostname
        ).to_set.freeze
        # Integer-valued options, where 0 (OpenSSL::SSL::VERIFY_NONE) means off; elsewhere 0 is truthy and keeps verification on.
        ZERO_DISABLES_KEYS = %w(verify_ssl ssl_verifypeer ssl_verifyhost).to_set.freeze
        HTTPARTY_FALSE_DISABLES_KEYS = %w(verify verify_peer).to_set.freeze
        OPTION_SETTERS = (TLS_MODE_KEYS + FALSE_DISABLES_KEYS + ZERO_DISABLES_KEYS).map { |key| :"#{key}=" }
        RESTRICT_ON_SEND = (%i(verify_mode= verify= []= const_set) + OPTION_SETTERS).uniq.freeze

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

        # @!method zero_literal?(node)
        def_node_matcher :zero_literal?, <<~PATTERN
          (int 0)
        PATTERN

        # @!method none_literal?(node)
        def_node_matcher :none_literal?, <<~PATTERN
          {#zero_literal? (sym {:none :NONE}) (str {"none" "NONE"})}
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
          if tls_option_disabled?(key, node.value, ssl_scope: ssl_options_pair?(node)) || httparty_verify_disabled?(node, key)
            TLS_MSG
          elsif host_key_verification_disabled?(node, key)
            SSH_MSG
          end
        end

        def tls_option_disabled?(key, value, ssl_scope:)
          case key
          when "verify_mode" then verify_none_constant?(value) || (ssl_scope && none_literal?(value))
          when "verify" then ssl_scope && value.false_type?
          when *TLS_MODE_KEYS then verify_none_constant?(value) || none_literal?(value)
          else
            (FALSE_DISABLES_KEYS.include?(key) && value.false_type?) ||
              (ZERO_DISABLES_KEYS.include?(key) && (zero_literal?(value) || verify_none_constant?(value)))
          end
        end

        def ssl_options_pair?(node)
          options_owner = node.parent.parent
          options_owner&.pair_type? && option_key(options_owner.key)&.to_s == "ssl"
        end

        def httparty_verify_disabled?(node, key)
          HTTPARTY_FALSE_DISABLES_KEYS.include?(key) && node.value.false_type? && httparty_call?(node.parent.parent)
        end

        def host_key_verification_disabled?(node, key)
          return false unless disabling_host_key_verifier?(node.value)

          key == "verify_host_key" || (key == "paranoid" && net_ssh_start?(node.parent.parent))
        end

        def tls_disabling_call?(node)
          case node.method_name
          when :[]= then index_assignment_disables?(node)
          when :const_set then verify_peer_const_set?(node)
          else setter_disables?(node)
          end
        end

        def setter_disables?(node)
          value = node.first_argument
          return false unless value

          tls_option_disabled?(node.method_name.to_s.delete_suffix("="), value, ssl_scope: faraday_ssl_receiver?(node.receiver))
        end

        def index_assignment_disables?(node)
          key_node, value = *node.arguments
          key = option_key(key_node)&.to_s
          return false unless key && value

          tls_option_disabled?(key, value, ssl_scope: faraday_ssl_receiver?(node.receiver))
        end

        def verify_peer_const_set?(node)
          name_node, value = *node.arguments
          return false unless option_key(name_node)&.to_s == "VERIFY_PEER" && value

          in_openssl_ssl = node.receiver ? openssl_ssl_namespace?(node.receiver) : inside_openssl_ssl_module?(node)
          in_openssl_ssl && verify_peer_override?(value)
        end

        def verify_peer_override?(value)
          return false unless value

          verify_none_constant?(value) || zero_literal?(value)
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
