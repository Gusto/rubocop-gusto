# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags ops, debug and admin web UIs mounted in routes without authentication.
      #
      # These engines ship without authentication. A mount passes inside an `AuthenticationMethods` block,
      # when the engine is wrapped in middleware, or behind an explicit development-environment check;
      # any other environment check is not a gate, since shared non-production environments hold real data.
      #
      # @example
      #   # bad
      #   mount Sidekiq::Web, at: "/sidekiq"
      #   mount Karafka::Web::App => "/karafka"
      #
      #   # bad
      #   unless %w(staging production).include?(Gusto::Config.environment)
      #     mount Sidekiq::Web, at: "/sidekiq"
      #   end
      #
      #   # good
      #   mount Sidekiq::Web, at: "/sidekiq" if Rails.env.development?
      #
      #   # good
      #   authenticate(:user, ->(user) { user.engineer? }) do
      #     mount Sidekiq::Web, at: "/sidekiq"
      #   end
      #
      #   # good
      #   mount EngineWithMiddleware.wrap(Sidekiq::Web, Rack::SessionAuth), at: "/sidekiq"
      class UnauthenticatedOpsMount < Base
        MSG = "Mount `%{engine}` inside an authentication block (%{methods}) or wrap it in authenticating middleware."
        RESTRICT_ON_SEND = %i(mount).freeze

        DEFAULT_ENGINES = %w(
          Sidekiq::Web
          Karafka::Web::App
          Gusto::Karafka::Engine
          Flipper::UI
        ).freeze
        DEFAULT_AUTHENTICATION_METHODS = %w(authenticate authenticated).freeze

        # @!method mounted_engine(node)
        #   Matches the engine constant in `mount Engine, at: ...` and `mount Engine => ...`,
        #   including engines built by a call on their constant such as `Flipper::UI.app(Flipper)`.
        def_node_matcher :mounted_engine, <<~PATTERN
          (send nil? :mount {$const (send $const ...) (hash (pair {$const (send $const ...)} _) ...)} ...)
        PATTERN

        # @!method development_check?(node)
        def_node_matcher :development_check?, <<~PATTERN
          {
            (send (send (const {nil? cbase} :Rails) :env) :development?)
            (send _ :== (str "development"))
            (send (str "development") :== _)
          }
        PATTERN

        def on_send(node)
          mounted_engine(node) do |engine|
            engine_name = engine.const_name
            next unless engines.include?(engine_name)
            next if inside_authentication_block?(node)
            next if development_only?(node)

            add_offense(node, message: format(MSG, engine: engine_name, methods: methods_description))
          end
        end
        alias_method :on_csend, :on_send

        private

        def inside_authentication_block?(node)
          node.each_ancestor(:any_block).any? do |block|
            block.receiver.nil? && authentication_methods.include?(block.method_name.to_s)
          end
        end

        def development_only?(node)
          node.each_ancestor(:if).any? do |if_node|
            next false unless development_check?(if_node.condition)

            development_branch = if_node.unless? ? if_node.else_branch : if_node.if_branch
            development_branch.equal?(node) || node.each_ancestor.any? { |ancestor| ancestor.equal?(development_branch) }
          end
        end

        def methods_description
          authentication_methods.map { |name| "`#{name}`" }.join("/")
        end

        def engines
          @engines ||= Array(cop_config.fetch("Engines", DEFAULT_ENGINES)).to_set { |name| name.to_s.delete_prefix("::") }
        end

        def authentication_methods
          @authentication_methods ||= Array(cop_config.fetch("AuthenticationMethods", DEFAULT_AUTHENTICATION_METHODS)).map(&:to_s)
        end
      end
    end
  end
end
