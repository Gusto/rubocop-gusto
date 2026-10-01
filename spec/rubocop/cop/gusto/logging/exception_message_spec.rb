# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Logging::ExceptionMessage, :config do
  let(:cop_config) { {} }

  it_behaves_like "a logging cop", "e.message", "begin; work; rescue => e; %s; end"

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

    it "flags an outer rescued exception inside a nested rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => outer_error
          begin
            recover
          rescue => inner_error
            logger.error(outer_error.message)
                         ^^^^^^^^^^^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
            logger.error(inner_error.message)
                         ^^^^^^^^^^^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
          end
        end
      RUBY
    end

    it "does not flag a block parameter shadowing the rescued exception" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => error
          messages.each do |error|
            logger.error(error.message)
          end
        end
      RUBY
    end

    it "does not flag shadowed variables inside a log message block" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => error
          logger.error { messages.map { |error| error.message } }
        end
      RUBY
    end

    it "does not flag block-local variables shadowing the rescued exception" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => error
          messages.each do |message; error|
            error = message
            logger.error(error.message)
          end
        end
      RUBY
    end

    it "does not flag destructured block parameters shadowing the rescued exception" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => error
          messages.each do |(error, context)|
            logger.error(error.message)
          end
        end
      RUBY
    end

    it "does not flag a method parameter with the same name as an outer exception" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => error
          def report(error)
            logger.error(error.message)
          end
        end
      RUBY
    end

    it "flags an exception in the logger arguments before block parameter binding" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => error
          logger.error(error.message) { |error| error.message }
                       ^^^^^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
        end
      RUBY
    end

    it "flags an outer exception inside a rescue without a local binding" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => error
          begin
            recover
          rescue
            logger.error(error.message)
                         ^^^^^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
          end
        end
      RUBY
    end

    it "flags a rescued exception through a block with unrelated parameters" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => error
          messages.each do |message|
            logger.error(error.message)
                         ^^^^^^^^^^^^^ Avoid logging exception messages in rescue blocks — they may contain PII. Log `e.class.name` or a static description instead.
          end
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

    it "does not confuse local variables with an instance-variable rescue binding" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => @error
          error = build_safe_message
          logger.error(error.message)
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
