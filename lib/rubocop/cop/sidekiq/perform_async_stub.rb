# frozen_string_literal: true

module RuboCop
  module Cop
    module Sidekiq
      # Checks that `perform_async` calls to enqueue Sidekiq jobs are not stubbed
      #
      # @example
      #   # bad
      #   allow(Foo).to receive(:perform_async)
      #   expect(Foo).to receive(:perform_async)
      #   expect(Foo).not_to receive(:perform_async)
      #
      #   # bad - the stub it verifies is itself the offense, and it may have been
      #   # set up in a shared context this cop cannot see
      #   expect(Foo).to have_received(:perform_async)
      #
      #   # good (still invokes the real method)
      #   allow(Foo).to receive(:perform_async).and_call_original
      #   expect(Foo).to receive(:perform_async).with(arg).and_call_original
      #   allow(Foo).to receive(:perform_async).and_wrap_original { |m, *args| m.call(*args) }
      #
      #   # good (checking enqueued jobs)
      #   expect { subject }.to change(Foo.jobs, :count).by(n)
      #   expect { subject }.not_to change(Foo.jobs, :count)
      #   expect(Foo.jobs.count).to eq(n)
      #
      #   # good - there is no other way to make an enqueue fail. Sidekiq's testing API
      #   # pushes onto Foo.jobs and offers no failure injection, so a spec covering the
      #   # rescue around an enqueue has to raise from the stub.
      #   allow(Foo).to receive(:perform_async).and_raise(StandardError, "redis down")
      #
      # @safety
      #   Autocorrect is unsafe: it appends `.and_call_original` on positive `receive` only, which runs
      #   the real `perform_async` during the example (may enqueue jobs, hit external code, or
      #   change expectations vs a pure stub). There is no autocorrect for `not_to` / `to_not receive`,
      #   since `.and_call_original` would not apply to a negative expectation, nor for
      #   `have_received`, whose stub lives elsewhere. Autocorrect is also suppressed when the
      #   expectation uses a block, since appending `.and_call_original` would rebind the block to
      #   the wrong method.
      class PerformAsyncStub < Base
        extend AutoCorrector

        MSG = "Prefer checking enqueued jobs over stubbing `perform_async`."
        MSG_RECEIVE = "Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`."
        RESTRICT_ON_SEND = %i(receive have_received).freeze

        # Chain modifiers that leave the real `perform_async` reachable, so the example is not
        # replacing the enqueue with a canned result. `and_raise` belongs here even though it
        # never calls the original: simulating a failed enqueue is the one thing Sidekiq's
        # testing API cannot express, so a spec covering the rescue has no other route.
        ALLOWED_CHAIN = %i(and_call_original and_wrap_original and_raise).freeze

        # @!method stub_perform_async?(node)
        def_node_matcher :stub_perform_async?, <<~PATTERN
          (send nil? {:receive :have_received} (sym :perform_async))
        PATTERN

        def on_send(node)
          return unless stub_perform_async?(node)
          # `have_received` only verifies a stub that was installed somewhere else, possibly in a
          # shared context or support file out of this cop's reach, so it is flagged on sight and
          # there is nothing local to autocorrect.
          return add_offense(node) if node.method?(:have_received)

          negative_expectation = false
          allowed_chain = false

          current = node.parent
          while current&.call_type?
            negative_expectation = true if current.method?(:not_to) || current.method?(:to_not)
            allowed_chain = true if ALLOWED_CHAIN.include?(current.method_name)

            current = current.parent
          end

          return add_offense(node) if negative_expectation
          return if allowed_chain

          tail = message_expectation_chain_tail(node)
          return add_offense(node, message: MSG_RECEIVE) if tail.parent&.block_type?

          add_offense(node, message: MSG_RECEIVE) do |corrector|
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
