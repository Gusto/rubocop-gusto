# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Logging::ExceptionMessage, :config do
  let(:cop_config) { {} }

  describe "exception messages in rescue blocks" do
    it "flags e.message in interpolation within rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Failed: \#{e.message}")
                                        ^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "flags e.to_s in interpolation within rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Failed: \#{e.to_s}")
                                        ^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "flags e.inspect within rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Failed: \#{e.inspect}")
                                        ^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "flags e.message as direct argument within rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue StandardError => error
          logger.error(error.message)
                       ^^^^^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "flags e.to_s as direct argument within rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error(e.to_s)
                             ^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "flags with typed rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue JSON::ParserError => e
          Rails.logger.error("Parse error: \#{e.message}")
                                             ^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "does not flag non-logger calls" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          notifier.error("Failed: \#{e.message}")
        end
      RUBY
    end

    it "does not flag e.class.name" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Failed: \#{e.class.name}")
        end
      RUBY
    end

    it "does not flag e.message outside rescue" do
      expect_no_offenses(<<~RUBY)
        error = get_error
        Rails.logger.info("Error: \#{error.message}")
      RUBY
    end

    it "does not flag .message on non-exception variables in rescue" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          msg = build_safe_message(e)
          Rails.logger.error("Failed: \#{msg.something}")
        end
      RUBY
    end

    it "does not flag .to_s on non-exception variable in rescue" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          msg = "safe"
          Rails.logger.info(msg.to_s)
        end
      RUBY
    end

    it "does not flag .message on method return in rescue" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error(build_message(e).message)
        end
      RUBY
    end

    it "does not flag .message on send-type receiver in rescue (not the exception var)" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Info: \#{some_service.message}")
        end
      RUBY
    end

    it "does not flag e.message when rescue has no variable" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue
          Rails.logger.error("Something failed")
        end
      RUBY
    end

    it "does not flag bare .message call (no receiver) inside rescue" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error(message)
        end
      RUBY
    end
  end
end
