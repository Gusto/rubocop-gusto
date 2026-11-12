# frozen_string_literal: true

RSpec.describe RuboCop::Gusto::Plugin do
  it "functions as a plugin" do
    about = described_class.new.about
    expect(about.name).to eq("rubocop-gusto")
    expect(about.version).to eq(RuboCop::Gusto::VERSION)
    expect(about.homepage).to eq("https://github.com/Gusto/rubocop-gusto")
    expect(about.description).to eq("A collection of Gusto's standard RuboCop cops and rules.")
  end

  it "points rubocop at the gem's default config" do
    rules = described_class.new.rules(nil)
    expect(rules.type).to eq(:path)
    expect(rules.value.to_s).to end_with("config/default.yml")
  end

  it "registers the gem's obsoletion rules so renamed cops report their new name" do
    described_class.new.rules(nil)

    expect(RuboCop::ConfigObsoletion.files.map(&:to_s)).to include(a_string_ending_with("config/obsoletion.yml"))
  end

  it "reports the new name for a cop that moved into the Gusto/Graphql department" do
    described_class.new.rules(nil)
    config = RuboCop::Config.new({ "Graphql/PaginateArrays" => { "Enabled" => true } }, "/config/.rubocop.yml")

    expect { RuboCop::ConfigObsoletion.new(config).reject_obsolete! }
      .to raise_error(RuboCop::ValidationError, /`Graphql\/PaginateArrays` cop has been moved to `Gusto\/Graphql\/PaginateArrays`/)
  end

  it "reports the rubocop-graphql name for a cop that was contributed upstream instead" do
    described_class.new.rules(nil)
    config = RuboCop::Config.new({ "Graphql/PreventFloat" => { "Enabled" => true } }, "/config/.rubocop.yml")

    expect { RuboCop::ConfigObsoletion.new(config).reject_obsolete! }
      .to raise_error(RuboCop::ValidationError, /`Graphql\/PreventFloat` cop has been renamed to `GraphQL\/DisallowedTypes`/)
  end

  it "leaves the rubocop-graphql `GraphQL` department alone" do
    described_class.new.rules(nil)
    config = RuboCop::Config.new({ "GraphQL/FieldDescription" => { "Enabled" => true } }, "/config/.rubocop.yml")

    expect { RuboCop::ConfigObsoletion.new(config).reject_obsolete! }.not_to raise_error
  end

  it "keeps applying config for a cop moved under Gusto/ to its new name" do
    described_class.new.rules(nil)
    config = RuboCop::Config.new({ "Rack/LowercaseHeaderKeys" => { "Enabled" => false } }, "/config/.rubocop.yml")
    obsoletion = RuboCop::ConfigObsoletion.new(config)

    expect { obsoletion.reject_obsolete! }.not_to raise_error
    expect(obsoletion.warnings).to include(/`Rack\/LowercaseHeaderKeys` cop has been renamed to `Gusto\/LowercaseHeaders`/)
    expect { expect(config.for_cop("Gusto/LowercaseHeaders")).to include("Enabled" => false) }
      .to output(/Using `Rack\/LowercaseHeaderKeys` configuration/).to_stderr
  end

  it "reports a move into the Gusto/Sidekiq department as a warning" do
    described_class.new.rules(nil)
    config = RuboCop::Config.new({ "Sidekiq/PerformAsyncStub" => { "Enabled" => true } }, "/config/.rubocop.yml")
    obsoletion = RuboCop::ConfigObsoletion.new(config)

    expect { obsoletion.reject_obsolete! }.not_to raise_error
    expect(obsoletion.warnings).to include(/`Sidekiq\/PerformAsyncStub` cop has been moved to `Gusto\/Sidekiq\/PerformAsyncStub`/)
  end

  it "renames every obsolete cop to one that exists" do
    moved = YAML.load_file("config/obsoletion.yml").fetch("renamed")
    new_names = moved.values.map { |rule| rule.is_a?(Hash) ? rule.fetch("new_name") : rule }
    registered = RuboCop::Cop::Registry.global.cops.map(&:cop_name)

    expect(new_names.uniq - registered).to be_empty
  end

  it "accounts for every cop in the Gusto/Graphql department" do
    moved = YAML.load_file("config/obsoletion.yml").fetch("renamed")
    added_since_the_move = %w(Gusto/Graphql/ResourceFromContext)
    ours = RuboCop::Cop::Registry.global.cops.map(&:cop_name).grep(%r(\AGusto/Graphql/))

    expect(ours - moved.values - added_since_the_move).to be_empty
  end

  it "keeps every Gusto-authored cop under the Gusto department" do
    gem_cops = RuboCop::Cop::Registry.global.cops.select do |cop|
      Object.const_source_location(cop.name)&.first&.start_with?(File.expand_path("../../../lib", __dir__))
    end

    expect(gem_cops.map(&:cop_name).reject { |name| name.start_with?("Gusto/", "InternalAffairs/") }).to be_empty
  end
end
