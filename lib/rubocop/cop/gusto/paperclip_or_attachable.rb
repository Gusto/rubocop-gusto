# typed: ignore
# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags use of Paperclip and the internal Attachable module for file attachments.
      #
      # Paperclip is unmaintained and Attachable was a transitional wrapper around it.
      # All new file attachment code must use ActiveStorage, which is maintained as part
      # of Rails and integrates with cloud storage providers via a standard API.
      # Existing Paperclip/Attachable usage is being migrated incrementally.
      #
      # Flagged methods: +has_attached_file+, +has_pdf_attachment+, +has_attachment+.
      #
      # @example bad
      #   has_attached_file :avatar
      #
      # @example good
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
