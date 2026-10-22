# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags calls to `Timeout.timeout`.
      #
      # `Timeout.timeout` stops its block by calling `Thread#raise` from a
      # watcher thread, so the exception can land on any line of the block,
      # including inside an `ensure` clause or halfway through a database write
      # or a connection checkout. That can leak locks, return a half-read socket
      # to a pool, or leave records partially updated. There is no safe way to
      # interrupt an arbitrary block of code; see
      # https://jvns.ca/blog/2015/11/27/why-rubys-timeout-is-dangerous-and-thread-dot-raise-is-terrifying/
      #
      # Instead, use the timeout the waiting operation itself supports, which
      # fails at a known point: `Net::HTTP#read_timeout`, a database
      # `statement_timeout`, `IO#timeout=`, `Queue#pop(timeout:)`, or a deadline
      # checked with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`.
      #
      # `Timeout` is a constant, so it is never nil and safe navigation
      # (`Timeout&.timeout`) is never used; the cop only handles `on_send`.
      #
      # @example
      #   # bad
      #   Timeout.timeout(5) { http.get(path) }
      #   ::Timeout.timeout(5, MyError) { do_work }
      #
      #   # good
      #   http.read_timeout = 5
      #   http.get(path)
      class TimeoutTimeout < Base
        MSG = "Avoid `Timeout.timeout`; it interrupts the block with `Thread#raise` at an arbitrary point. " \
              "Use the timeout option of the operation being waited on instead, " \
              "such as `Net::HTTP#read_timeout` or a database `statement_timeout`."
        RESTRICT_ON_SEND = %i(timeout).freeze

        # @!method timeout_timeout?(node)
        def_node_matcher :timeout_timeout?, <<~PATTERN
          (send (const {nil? cbase} :Timeout) :timeout ...)
        PATTERN

        def on_send(node)
          add_offense(node) if timeout_timeout?(node)
        end
      end
    end
  end
end
