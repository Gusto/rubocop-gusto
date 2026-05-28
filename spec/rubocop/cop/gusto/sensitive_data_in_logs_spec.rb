# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::SensitiveDataInLogs, :config do
  let(:cop_config) { {} }

  describe "Pattern 1: PII accessor methods in log interpolation" do
    it "flags .email in interpolation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("User: \#{user.email}")
                                   ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
      RUBY
    end

    it "flags .ssn in interpolation" do
      expect_offense(<<~RUBY)
        logger.warn("Employee SSN: \#{employee.ssn}")
                                     ^^^^^^^^^^^^ Avoid logging PII accessor `.ssn`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
      RUBY
    end

    it "flags .first_name in interpolation" do
      expect_offense(<<~RUBY)
        Sidekiq.logger.error("Name: \#{user.first_name}")
                                      ^^^^^^^^^^^^^^^ Avoid logging PII accessor `.first_name`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
      RUBY
    end

    it "flags .phone via safe navigation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Phone: \#{user&.phone}")
                                    ^^^^^^^^^^^ Avoid logging PII accessor `.phone`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
      RUBY
    end

    it "flags multiple PII accessors in one statement" do
      expect_offense(<<~RUBY)
        Rails.logger.info("User: \#{user.email} - \#{user.ssn}")
                                   ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
                                                   ^^^^^^^^ Avoid logging PII accessor `.ssn`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
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

    context "with custom PiiMethods config" do
      let(:cop_config) { { "PiiMethods" => ["custom_secret"] } }

      it "flags configured custom method" do
        expect_offense(<<~RUBY)
          Rails.logger.info("Secret: \#{obj.custom_secret}")
                                       ^^^^^^^^^^^^^^^^^ Avoid logging PII accessor `.custom_secret`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
        RUBY
      end

      it "does not flag default methods when overridden" do
        expect_no_offenses(<<~RUBY)
          Rails.logger.info("Email: \#{user.email}")
        RUBY
      end
    end

    context "when CheckPiiAccessors is disabled" do
      let(:cop_config) { { "CheckPiiAccessors" => false } }

      it "does not flag PII accessors" do
        expect_no_offenses(<<~RUBY)
          Rails.logger.info("User: \#{user.email}")
        RUBY
      end
    end
  end

  describe "Pattern 2: raw params logging" do
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

    it "flags raw params in string interpolation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Received: \#{params}")
                                       ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
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

    it "does not flag params.require" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.require(:id))
      RUBY
    end

    context "when CheckRawParams is disabled" do
      let(:cop_config) { { "CheckRawParams" => false } }

      it "does not flag raw params" do
        expect_no_offenses(<<~RUBY)
          Rails.logger.info(params)
        RUBY
      end
    end
  end

  describe "Pattern 3: e.message in rescue blocks" do
    let(:cop_config) { { "CheckErrorMessage" => true } }

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

    context "when CheckErrorMessage is disabled" do
      let(:cop_config) { { "CheckErrorMessage" => false } }

      it "does not flag e.message" do
        expect_no_offenses(<<~RUBY)
          begin
            something
          rescue => e
            Rails.logger.error("Failed: \#{e.message}")
          end
        RUBY
      end
    end
  end

  describe "Pattern 4: response.body in log calls" do
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

    context "when CheckResponseBody is disabled" do
      let(:cop_config) { { "CheckResponseBody" => false } }

      it "does not flag response.body" do
        expect_no_offenses(<<~RUBY)
          Rails.logger.info("Response: \#{response.body}")
        RUBY
      end
    end
  end

  describe "Pattern 5: object serialization in log calls" do
    it "flags .inspect as direct argument" do
      expect_offense(<<~RUBY)
        Rails.logger.info(user.inspect)
                          ^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags .inspect in interpolation" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Record: \#{record.inspect}")
                                     ^^^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags .to_json as direct argument" do
      expect_offense(<<~RUBY)
        logger.info(employee.to_json)
                    ^^^^^^^^^^^^^^^^ Avoid logging `.to_json` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags .as_json" do
      expect_offense(<<~RUBY)
        Rails.logger.warn(company.as_json)
                          ^^^^^^^^^^^^^^^ Avoid logging `.as_json` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags .to_yaml" do
      expect_offense(<<~RUBY)
        Rails.logger.info(record.to_yaml)
                          ^^^^^^^^^^^^^^ Avoid logging `.to_yaml` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags .attributes" do
      expect_offense(<<~RUBY)
        Rails.logger.info(user.attributes)
                          ^^^^^^^^^^^^^^^ Avoid logging `.attributes` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "does not flag .to_json on a hash literal" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info({ id: 1, status: "ok" }.to_json)
      RUBY
    end

    it "does not flag .to_json on an array literal" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info([1, 2, 3].to_json)
      RUBY
    end

    it "does not flag .to_json on a string literal" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("hello".to_json)
      RUBY
    end

    it "does not flag .inspect on nil" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(nil.inspect)
      RUBY
    end

    it "does not flag .inspect on an integer" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(42.inspect)
      RUBY
    end

    context "when CheckObjectSerialization is disabled" do
      let(:cop_config) { { "CheckObjectSerialization" => false } }

      it "does not flag .inspect" do
        expect_no_offenses(<<~RUBY)
          Rails.logger.info(user.inspect)
        RUBY
      end
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

  describe "edge cases" do
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

    it "does not flag calls without arguments" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info
      RUBY
    end

    it "handles block-form logging" do
      expect_offense(<<~RUBY)
        Rails.logger.info { "User: \#{user.email}" }
                                     ^^^^^^^^^^ Avoid logging PII accessor `.email`. Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`.
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

    it "handles response.body with local variable assignment" do
      expect_offense(<<~RUBY)
        response = make_request
        Rails.logger.info(response.body)
                          ^^^^^^^^^^^^^ Avoid logging HTTP response bodies which may contain PII. Log `response.status` and a request identifier instead.
      RUBY
    end

    it "does not flag response.body on chained receiver" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(client.get.body)
      RUBY
    end

    it "flags object serialization via safe navigation" do
      expect_offense(<<~RUBY)
        Rails.logger.info(user&.to_json)
                          ^^^^^^^^^^^^^ Avoid logging `.to_json` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    context "with CheckErrorMessage enabled" do
      let(:cop_config) { { "CheckErrorMessage" => true } }

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
    end

    it "does not flag object serialization methods that are not in the checked set" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(user.to_s)
      RUBY
    end

    it "handles params in interpolation inside rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.info("Params: \#{params}")
                                       ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
        end
      RUBY
    end

    it "flags params.to_yaml" do
      expect_offense(<<~RUBY)
        Rails.logger.info(params.to_yaml)
                          ^^^^^^^^^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    context "with CheckErrorMessage enabled for rescue edge cases" do
      let(:cop_config) { { "CheckErrorMessage" => true } }

      it "does not flag .message on send-type receiver in rescue (not the exception var)" do
        expect_no_offenses(<<~RUBY)
          begin
            something
          rescue => e
            Rails.logger.error("Info: \#{some_service.message}")
          end
        RUBY
      end
    end

    it "does not flag .inspect without a receiver" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(inspect)
      RUBY
    end

    it "does not flag .body without a receiver" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(body)
      RUBY
    end

    it "registers raw params in non-send parent context" do
      expect_offense(<<~RUBY)
        Rails.logger.info("Data: \#{params}")
                                   ^^^^^^ Avoid logging raw `params` which may contain PII. Use `params.slice(...)` or `params.permit(...)` to select safe fields.
      RUBY
    end

    context "with CheckErrorMessage enabled for rescue no-variable cases" do
      let(:cop_config) { { "CheckErrorMessage" => true } }

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

    it "does not flag params when parent is safe_params method call" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.slice(:id))
      RUBY
    end
  end
end
