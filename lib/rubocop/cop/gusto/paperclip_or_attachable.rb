# typed: ignore
# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for usage of the deprecated Paperclip macros
      # (`has_attached_file`) and the internal Attachable macros
      # (`has_pdf_attachment`, `has_attachment`). Paperclip is no longer
      # maintained and has known security vulnerabilities. New file attachment
      # functionality should use ActiveStorage, which ships with Rails.
      #
      # @example
      #   # bad
      #   class User < ApplicationRecord
      #     has_attached_file :avatar, styles: { thumb: '100x100>' }
      #   end
      #
      #   # bad
      #   class Document < ApplicationRecord
      #     has_pdf_attachment :file
      #   end
      #
      #   # good
      #   class User < ApplicationRecord
      #     has_one_attached :avatar
      #   end
      #
      #   # good
      #   class Document < ApplicationRecord
      #     has_one_attached :file
      #   end
      #
      class PaperclipOrAttachable < Base
        MSG = "No more new paperclip or Attachable are allowed. New attachments should use ActiveStorage instead"
        RESTRICT_ON_SEND = %i[has_attached_file has_pdf_attachment has_attachment].freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
