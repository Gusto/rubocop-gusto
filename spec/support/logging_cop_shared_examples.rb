# frozen_string_literal: true

RSpec.shared_examples "a logging cop" do |expression, context = "%s"|
  operators = %w(. &.)
  [
    "Rails.logger", "::Rails.logger", "Sidekiq.logger", "::Sidekiq.logger", "logger",
    'Rails.logger.tagged("request")', 'logger.tagged("a").tagged("b")',
    'Sidekiq.logger.tagged("job")', 'Rails.logger&.tagged("request")',
  ].each do |receiver|
    operators.each do |operator|
      it "detects sensitive values through #{receiver}#{operator}info" do
        offenses = inspect_source(format(context, "#{receiver}#{operator}info(#{expression})"))

        expect(offenses.map { |offense| offense.location.source }).to eq([expression])
      end
    end
  end

  it "detects sensitive values in a tagged logger's message block" do
    offenses = inspect_source(format(context, "Rails.logger.tagged('request').info { #{expression} }"))

    expect(offenses.map { |offense| offense.location.source }).to eq([expression])
  end

  ["tracker", 'tracker.tagged("request")', 'Rails.logger.child("request")', "nil"].each do |receiver|
    it "does not treat #{receiver} as a supported logger" do
      expect_no_offenses(format(context, "#{receiver}.info(#{expression})"))
    end
  end
end
