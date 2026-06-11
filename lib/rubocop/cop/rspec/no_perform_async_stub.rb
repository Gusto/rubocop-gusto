# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Checks that `perform_async` calls to enqueue Sidekiq jobs are not stubbed
      #
      # @example
      #   # bad
      #   allow(Foo).to receive(:perform_async)
      #   expect(Foo).to receive(:perform_async)
      #   expect(Foo).not_to receive(:perform_async)
      #
      #   # good (still invokes the real method)
      #   allow(Foo).to receive(:perform_async).and_call_original
      #   expect(Foo).to receive(:perform_async).with(arg).and_call_original
      #
      #   # good (checking enqueued jobs)
      #   expect { subject }.to change(Foo.jobs, :count).by(n)
      #   expect { subject }.not_to change(Foo.jobs, :count)
      #   expect(Foo.jobs.count).to eq(n)
      #
      #   # good (only checks previously pre-stubbed objects)
      #   expect(Foo).to have_received(:perform_async)
      #
      # @safety
      #   Autocorrect is unsafe: it appends `.and_call_original` on positive `receive` only, which runs
      #   the real `perform_async` during the example (may enqueue jobs, hit external code, or
      #   change expectations vs a pure stub). There is no autocorrect for `not_to` / `to_not receive`,
      #   since `.and_call_original` would not apply to a negative expectation.
      class NoPerformAsyncStub < Base
        extend AutoCorrector

        MSG = "Prefer checking enqueued jobs over stubbing `perform_async`."
        MSG_RECEIVE = "Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`."
        RESTRICT_ON_SEND = %i(receive).freeze

        # TODO: this should match on perform_async, not on receive, requires pattern update
        # @!method stub_perform_async?(node)
        def_node_matcher :stub_perform_async?, <<~PATTERN
          (send nil? :receive (sym :perform_async))
        PATTERN

        def on_send(node)
          return unless stub_perform_async?(node)

          negative_expectation = false
          calls_original = false

          current = node.parent
          while current&.call_type?
            negative_expectation = true if current.method?(:not_to) || current.method?(:to_not)
            calls_original = true if current.method?(:and_call_original)

            current = current.parent
          end

          return add_offense(node) if negative_expectation
          return if calls_original # already have .and_call_original, not an offense

          add_offense(node, message: MSG_RECEIVE) do |corrector|
            tail = message_expectation_chain_tail(node)
            corrector.insert_after(tail, ".and_call_original")
          end
        end

        alias_method :on_csend, :on_send

        private

        def message_expectation_chain_tail(node)
          tail = node
          loop do
            parent = tail.parent
            break unless parent&.call_type?
            break unless parent.receiver.equal?(tail)

            tail = parent
          end
          tail
        end
      end
    end
  end
end
