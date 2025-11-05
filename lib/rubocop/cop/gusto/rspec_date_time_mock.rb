# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Never mock time in specs. Use Rails Testing Time Helpers (eg `freeze_time` and `travel_to`) instead.
      # .and_call_original is allowed.
      #
      # @example
      #   # bad
      #   context 'time specific tests' do
      #     before { allow(Time).to receive(:now).and_return(current_time) }
      #     it 'does stuff in a fixed time' do
      #       subject
      #     end
      #   end
      #
      #   # good
      #   context 'time specific tests' do
      #     it 'does stuff in a fixed time' do
      #       freeze_time do
      #         subject
      #       end
      #     end
      #   end
      class RspecDateTimeMock < Base
        CLASSES = Set[
          :Date,
          :Time,
          :DateTime
        ].freeze
        MSG = "Don't mock #{CLASSES.join('/')} directly. Use Rails Testing Time Helpers (eg `freeze_time` and `travel_to`) instead.".freeze
        RESTRICT_ON_SEND = %i(to).freeze

        # Matches allow/expect with a time class (or chain) receiver and a `receive` or `receive_message_chain`
        # Examples matched:
        #   allow(Time).to receive(:now)
        #   allow(Time.zone).to receive(:now)
        #   allow(Time).to receive_message_chain(:zone, :now)
        #   expect(Date.today).to receive(:wday)
        # @!method time_mock?(node)
        def_node_matcher :time_mock?, <<~PATTERN
          (send
            (send nil? {:allow :expect} #rooted_in_time_class?)
            :to
            {
              (send (send nil? :receive _) ...)
              (send (send nil? :receive_message_chain ...) ...)
            }
          )
        PATTERN

        def on_send(node)
          time_mock?(node) do
            # Allow usages that explicitly call `.and_call_original` after `receive`
            # Example: allow(Time).to receive(:parse).and_call_original
            receive_chain = node.first_argument
            return if and_call_original_in_chain?(receive_chain)

            add_offense(node)
          end
        end

        private

        # Returns true if the given node is a const or a call chain whose root receiver
        # is one of the protected time classes (Date/Time/DateTime)
        def rooted_in_time_class?(node)
          return false if node.nil?

          current = node
          while current.respond_to?(:send_type?) && current.send_type?
            current = current.receiver
          end

          if current.nil?
            return false
          end

          return false unless current.const_type?

          # Accept both `Time` and `::Time` as root-level constants
          namespace = current.namespace
          is_root_level = namespace.nil? || namespace.cbase_type?
          is_root_level && CLASSES.include?(current.children[1])
        end

        def and_call_original_in_chain?(node)
          return false if node.nil?
          return false unless node.send_type?

          return true if node.method?(:and_call_original)

          node.each_descendant(:send).any? { |send_node| send_node.method?(:and_call_original) }
        end
      end
    end
  end
end
