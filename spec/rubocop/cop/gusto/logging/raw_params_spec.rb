# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Logging::RawParams, :config do
  let(:cop_config) { {} }

  it_behaves_like "a logging cop", "params"

  describe "raw params in log calls" do
    it "flags logging raw params as direct argument" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params)
                          ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags logging params.to_s" do
      expect_offense(<<~RUBY)
        logger.info(params.to_s)
                    ^^^^^^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags logging params.inspect" do
      expect_offense(<<~RUBY)
        Rails.logger.warn(params.inspect)
                          ^^^^^^^^^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags logging params.to_json" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params.to_json)
                          ^^^^^^^^^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags params serialization via safe navigation once" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params&.to_json)
                          ^^^^^^^^^^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags serialization of required params once" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params.require(:user).to_json)
                          ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags params.to_yaml" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params.to_yaml)
                          ^^^^^^^^^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags raw params in string interpolation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Received: \#{params}")
                                       ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "flags raw params in interpolation inside rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.info("Params: \#{params}")
                                       ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
        end
      RUBY
    end

    it "does not flag params.slice" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.slice(:id, :status))
      RUBY
    end

    it "does not flag params.permit" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.permit(:id))
      RUBY
    end

    it "does not flag params.except" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.except(:email, :ssn))
      RUBY
    end

    it "does not flag params.fetch" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.fetch(:id))
      RUBY
    end

    it "does not flag params.dig" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.dig(:user, :id))
      RUBY
    end

    it "does not flag params[:key]" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params[:id])
      RUBY
    end

    it "flags params.require on its own, which returns the whole nested hash" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params.require(:user))
                          ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "does not flag params.require followed by permit" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.require(:user).permit(:id))
      RUBY
    end

    it "does not flag params.require followed by a key lookup" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.require(:user)[:id])
      RUBY
    end

    [
      "params&.slice(:id)",
      "params&.fetch(:id)",
      "params.require(:user)&.permit(:id)",
      "params&.require(:user).permit(:id)",
      "params&.require(:user)&.permit(:id)",
      "params.slice(:id).to_json",
      "params&.require(:user)&.permit(:id)&.to_json",
    ].each do |expression|
      it "allows narrowed params in #{expression}" do
        expect_no_offenses("Rails.logger.info(#{expression})")
      end
    end

    it "flags required params via safe navigation without narrowing" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params&.require(:user))
                          ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end
  end

  describe "logger form coverage" do
    it "works with Rails.logger" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params)
                          ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "works with bare logger" do
      expect_offense(<<~RUBY)
        logger.info(params)
                    ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "works with Sidekiq.logger" do
      expect_offense(<<~RUBY)
        Sidekiq.logger.info(params)
                            ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    it "does not flag calls on non-logger receivers" do
      expect_no_offenses(<<~RUBY)
        some_service.info(params)
      RUBY
    end

    it "does not flag logger calls without a receiver" do
      expect_no_offenses(<<~RUBY)
        info(params)
      RUBY
    end
  end

  describe "log level coverage" do
    %w(debug info warn error fatal).each do |level|
      it "detects offenses in .#{level} calls" do
        expect_offense(<<~RUBY)
          Rails.logger.#{level}(params)
          #{' ' * (level.length + 14)}^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
        RUBY
      end
    end
  end
end
