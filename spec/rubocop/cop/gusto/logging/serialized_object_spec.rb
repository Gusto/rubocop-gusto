# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Logging::SerializedObject, :config do
  let(:cop_config) { {} }

  describe "serialization methods in log calls" do
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

    it "flags object serialization via safe navigation" do
      expect_offense(<<~RUBY)
        Rails.logger.info(user&.to_json)
                          ^^^^^^^^^^^^^ Avoid logging `.to_json` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "does not flag non-logger calls" do
      expect_no_offenses(<<~RUBY)
        tracker.info(employee.to_json)
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

    it "does not flag .to_json on a namespaced constant" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(Config::DEFAULTS.to_json)
      RUBY
    end

    it "does not flag .to_json without a receiver" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(to_json)
      RUBY
    end

    it "does not flag methods outside the checked set" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(user.to_s)
      RUBY
    end

    it "does not flag raw params, which RawParams reports" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.to_json)
        Rails.logger.info(params.as_json)
      RUBY
    end

    it "does not flag .inspect by default" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(user.inspect)
      RUBY
    end

    it "does not flag identifier-named values from the shipped allowlists" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Company \#{company_uuid.to_json} in state \#{state.to_json}")
      RUBY
    end

    it "still flags tax_id even though it ends with an allowed suffix" do
      expect_offense(<<~RUBY)
        Rails.logger.info(tax_id.to_json)
                          ^^^^^^^^^^^^^^ Avoid logging `.to_json` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end
  end

  describe "with CheckInspect enabled" do
    let(:cop_config) { { "CheckInspect" => true } }

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

    it "does not flag .inspect on a constant" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Mode: \#{MODE_SNAPSHOT.inspect}")
      RUBY
    end

    it "does not flag params.inspect, which RawParams reports" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(params.inspect)
      RUBY
    end

    it "does not flag e.inspect in rescue, which ExceptionMessage reports" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Failed: \#{e.inspect}")
        end
      RUBY
    end

    it "still flags .inspect on other objects within rescue" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue => e
          Rails.logger.error("Failed for \#{user.inspect}")
                                           ^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
        end
      RUBY
    end
  end

  context "with allowed receiver names and suffixes" do
    let(:cop_config) do
      {
        "AllowedReceiverNames" => %w(status),
        "AllowedReceiverSuffixes" => %w(_id _ids _uuid _type),
        "CheckInspect" => true,
        "PiiMethods" => %w(tax_id),
      }
    end

    it "does not flag a local variable matching an allowed suffix" do
      expect_no_offenses(<<~RUBY)
        company_uuid = find_company_uuid
        Rails.logger.info("Company: \#{company_uuid.inspect}")
      RUBY
    end

    it "does not flag an instance variable matching an allowed suffix" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(@event_type.inspect)
      RUBY
    end

    it "does not flag a method call matching an allowed name" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info("Status: \#{payment.status.inspect}")
      RUBY
    end

    it "does not flag a hash lookup whose literal key matches an allowed suffix" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(payment["payment_id"].inspect)
      RUBY
    end

    it "does not flag .to_json on a name matching an allowed suffix" do
      expect_no_offenses(<<~RUBY)
        Rails.logger.info(user_ids.to_json)
      RUBY
    end

    it "flags a name that only ends with an allowed exact name" do
      expect_offense(<<~RUBY)
        Rails.logger.info(marital_status.inspect)
                          ^^^^^^^^^^^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags a hash lookup with a non-literal key" do
      expect_offense(<<~RUBY)
        Rails.logger.info(payment[key].inspect)
                          ^^^^^^^^^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags a block result" do
      expect_offense(<<~RUBY)
        Rails.logger.info(users.select { |u| u.active? }.inspect)
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end

    it "flags an allowed suffix match that is also a PII method" do
      expect_offense(<<~RUBY)
        Rails.logger.info(tax_id.inspect)
                          ^^^^^^^^^^^^^^ Avoid logging `.inspect` on objects — it may serialize PII fields. Log specific safe attributes instead.
      RUBY
    end
  end
end
