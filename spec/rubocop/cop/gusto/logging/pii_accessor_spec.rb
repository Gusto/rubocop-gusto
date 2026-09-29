# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Logging::PiiAccessor, :config do
  let(:cop_config) { {} }

  describe "PII accessor methods in log calls" do
    it "flags .email in interpolation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("User: \#{user.email}")
                                   ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead.
      RUBY
    end

    it "flags .ssn in interpolation" do
      expect_offense(<<~RUBY)
        logger.warn("Employee SSN: \#{employee.ssn}")
                                     ^^^^^^^^^^^^ Avoid logging PII accessor `.ssn`. Log an identifier instead.
      RUBY
    end

    it "flags .first_name in interpolation" do
      expect_offense(<<~RUBY)
        Sidekiq.logger.error("Name: \#{user.first_name}")
                                      ^^^^^^^^^^^^^^^ Avoid logging PII accessor `.first_name`. Log an identifier instead.
      RUBY
    end

    it "flags .phone via safe navigation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Phone: \#{user&.phone}")
                                    ^^^^^^^^^^^ Avoid logging PII accessor `.phone`. Log an identifier instead.
      RUBY
    end

    it "flags multiple PII accessors in one statement" do
      expect_offense(<<~RUBY)
        Rails.logger.info("User: \#{user.email} - \#{user.ssn}")
                                   ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead.
                                                   ^^^^^^^^ Avoid logging PII accessor `.ssn`. Log an identifier instead.
      RUBY
    end

    it "does not flag .id in interpolation" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("User: \#{user.id}")
      RUBY
    end

    it "does not flag .uuid in interpolation" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Record: \#{record.uuid}")
      RUBY
    end

    it "does not flag .class.name in interpolation" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Type: \#{record.class.name}")
      RUBY
    end

    it "does not flag .count in interpolation" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Total: \#{records.count}")
      RUBY
    end

    it "does not flag plain strings" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("No interpolation here")
      RUBY
    end

    it "does not flag non-logger calls" do
      expect_no_offenses(<<~RUBY)
        some_object.info("User: \#{user.email}")
      RUBY
    end

    it "does not flag bare method calls without a receiver" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Value: \#{email}")
      RUBY
    end

    it "does not flag a predicate called on a PII accessor" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Has email: \#{user.email.present?}")
      RUBY
    end

    it "does not flag a predicate called on a PII accessor via safe navigation" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Missing SSN: \#{employee.ssn&.nil?}")
      RUBY
    end

    it "flags a non-predicate method called on a PII accessor" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Email: \#{user.email.downcase}")
                                    ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead.
      RUBY
    end

    context "with custom PiiMethods config" do
      let(:cop_config) { { "PiiMethods" => ["custom_secret"] } }

      it "flags configured custom method" do
        expect_offense(<<~RUBY)
          Rails.logger.info("Secret: \#{obj.custom_secret}")
                                       ^^^^^^^^^^^^^^^^^ Avoid logging PII accessor `.custom_secret`. Log an identifier instead.
        RUBY
      end

      it "does not flag default methods when overridden" do
        expect_no_offenses(<<~RUBY)
          Rails.logger.info("Email: \#{user.email}")
        RUBY
      end
    end

    context "with PiiMethods set on the Gusto/Logging department" do
      # rubocop:disable Gusto/UnreferencedLet -- read by RuboCop's :config shared context
      let(:other_cops) { { "Gusto/Logging" => { "PiiMethods" => ["custom_secret"] } } }
      # rubocop:enable Gusto/UnreferencedLet

      it "flags the department's methods" do
        expect_offense(<<~RUBY)
          Rails.logger.info("Secret: \#{obj.custom_secret}")
                                       ^^^^^^^^^^^^^^^^^ Avoid logging PII accessor `.custom_secret`. Log an identifier instead.
        RUBY
      end
    end
  end

  describe "log call shapes" do
    it "does not flag calls without arguments" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info
      RUBY
    end

    it "handles block-form logging" do
      expect_offense(<<~RUBY)
        Rails.logger.info { "User: \#{user.email}" }
                                     ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead.
      RUBY
    end

    it "does not register block-form logging with no body" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info {}
      RUBY
    end

    it "does not flag when block parent is not for this logger call" do
      expect_no_offenses(<<~RUBY)
        [1].each { |x| Rails.logger.info("count: \#{x}") }
      RUBY
    end
  end
end
