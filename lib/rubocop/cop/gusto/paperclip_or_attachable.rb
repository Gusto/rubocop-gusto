# typed: ignore
# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class PaperclipOrAttachable < Base
        MSG = 'No more new paperclip or Attachable are allowed. New attachments should use ActiveStorage instead'
        RESTRICT_ON_SEND = %i(has_attached_file has_pdf_attachment has_attachment).freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
