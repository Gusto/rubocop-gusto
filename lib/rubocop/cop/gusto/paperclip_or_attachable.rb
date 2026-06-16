# typed: ignore
# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Disallow new Paperclip / Attachable attachments. New attachments should
      # use ActiveStorage instead.
      #
      # @example
      #   # bad
      #   has_attached_file :avatar
      #
      #   # good
      #   has_one_attached :avatar
      class PaperclipOrAttachable < Base
        MSG = "No more new paperclip or Attachable are allowed. New attachments should use ActiveStorage instead"
        RESTRICT_ON_SEND = %i(has_attached_file has_pdf_attachment has_attachment).freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
