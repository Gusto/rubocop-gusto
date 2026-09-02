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
    config = RuboCop::Config.new({ "Graphql/PreventFloat" => { "Enabled" => true } }, "/config/.rubocop.yml")

    expect { RuboCop::ConfigObsoletion.new(config).reject_obsolete! }
      .to raise_error(RuboCop::ValidationError, /`Graphql\/PreventFloat` cop has been moved to `Gusto\/Graphql\/PreventFloat`/)
  end

  it "leaves the rubocop-graphql `GraphQL` department alone" do
    described_class.new.rules(nil)
    config = RuboCop::Config.new({ "GraphQL/FieldDescription" => { "Enabled" => true } }, "/config/.rubocop.yml")

    expect { RuboCop::ConfigObsoletion.new(config).reject_obsolete! }.not_to raise_error
  end

  it "supports every cop in the Gusto/Graphql department" do
    moved = YAML.load_file("config/obsoletion.yml").fetch("renamed")
    registered = RuboCop::Cop::Registry.global.cops.map(&:cop_name).grep(%r(\AGusto/Graphql/))

    expect(moved.values).to match_array(registered)
  end
end
