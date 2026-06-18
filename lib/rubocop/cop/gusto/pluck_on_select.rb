# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Do not use `.pluck` on `.select`.
      #
      # `.select` returns an ActiveRecord relation with only the selected columns marked for
      # retrieval. `.pluck` returns an array of column values. When chained, `.pluck` is unaware
      # of any directive passed to `.select` (e.g. column aliases or a DISTINCT clause), which
      # can cause unexpected behavior.
      #
      # @example Redundant select
      #   # bad
      #   User.select(:id).pluck(:id)
      #
      #   # good
      #   User.pluck(:id)
      #
      # @example Column alias — .pluck raises "Unknown column" because it ignores the alias
      #   # bad
      #   User.select('id AS id2').pluck('id2')
      #
      #   # good — use .select alone if you need the alias
      #   User.select(:id, 'id AS id2')
      #
      #   # good — use .pluck alone if you don't need the alias
      #   User.pluck(:id)
      #
      # @example DISTINCT — .pluck loads all rows, ignoring the DISTINCT from .select
      #   # bad
      #   User.select('DISTINCT email').pluck(:email)
      #
      #   # good
      #   User.distinct.pluck(:email)
      #
      class PluckOnSelect < Base
        RESTRICT_ON_SEND = %i[pluck].freeze
        MSG = "Do not use `.pluck` on `.select`."

        def on_send(node)
          return unless node.receiver

          receiver_node = node.receiver
          while receiver_node
            if receiver_node.call_type? && receiver_node.method?(:select)
              add_offense(node)
              break
            end
            receiver_node = receiver_node.receiver
          end
        end
        alias_method :on_csend, :on_send
      end
    end
  end
end
