# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Logging::ResponseBody, :config do
  let(:cop_config) { {} }

  it_behaves_like "a logging cop", "response.body"

  describe "response.body in log calls" do
    it "flags response.body in interpolation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Response: \#{response.body}")
                                       ^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags response.body as direct argument" do
      expect_offense(<<~RUBY)
        logger.info(response.body)
                    ^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags response.body with local variable assignment" do
      expect_offense(<<~RUBY)
        response = make_request
        Rails.logger.info(response.body)
                          ^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags response instance variables" do
      expect_offense(<<~RUBY)
        Rails.logger.info(@response.body)
                          ^^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags safe navigation on response instance variables" do
      expect_offense(<<~RUBY)
        logger.warn(@api_response&.body)
                    ^^^^^^^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "does not flag unrelated instance variables" do
      expect_no_offenses(<<~RUBY)
        logger.info(@email.body)
      RUBY
    end

    it "flags resp.body" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Data: \#{resp.body}")
                                   ^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags api_response.body" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Data: \#{api_response.body}")
                                   ^^^^^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags http_response.body" do
      expect_offense(<<~RUBY)
        logger.warn("Body: \#{http_response.body}")
                             ^^^^^^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "flags _response suffixed variables" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Body: \#{faraday_response.body}")
                                   ^^^^^^^^^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "does not flag non-logger calls" do
      expect_no_offenses(<<~RUBY)
        tracker.info(response.body)
      RUBY
    end

    it "does not flag response.status" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Status: \#{response.status}")
      RUBY
    end

    it "does not flag .body on non-response objects" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Body: \#{email_obj.body}")
      RUBY
    end

    it "does not flag .body on chained receivers" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Data: \#{client.response.body}")
      RUBY
    end

    it "does not flag .body on a chained method call" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(client.get.body)
      RUBY
    end

    it "does not flag .body without a receiver" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(body)
      RUBY
    end
  end
end
