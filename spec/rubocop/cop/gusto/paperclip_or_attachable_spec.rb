# frozen_string_literal: true

RSpec.describe(RuboCop::Cop::Gusto::PaperclipOrAttachable, :config) do
  it("registers an offense for has_attached_file method") do
    expect_offense(<<~RUBY)
      class User < ActiveRecord::Base
        has_attached_file :avatar
        ^^^^^^^^^^^^^^^^^^^^^^^^^ No more new paperclip or Attachable are allowed. New attachments should use ActiveStorage instead
      end
    RUBY
  end

  it("registers an offense has_attachment method") do
    expect_offense(<<~RUBY)
      class User < ActiveRecord::Base
        include Attachable
        has_attachment :avatar
        ^^^^^^^^^^^^^^^^^^^^^^ No more new paperclip or Attachable are allowed. New attachments should use ActiveStorage instead
      end
    RUBY
  end

  it("registers an offense has_pdf_attachment method") do
    expect_offense(<<~RUBY)
      class User < ActiveRecord::Base
        include Attachable
        has_pdf_attachment :avatar
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ No more new paperclip or Attachable are allowed. New attachments should use ActiveStorage instead
      end
    RUBY
  end

  it("does not register an offense for ActiveStorage has_one_attached") do
    expect_no_offenses(<<~RUBY)
      class User < ActiveRecord::Base
        has_one_attached :avatar
      end
    RUBY
  end
end
