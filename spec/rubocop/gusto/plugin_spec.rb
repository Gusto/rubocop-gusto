# frozen_string_literal: true

RSpec.describe RuboCop::Gusto::Plugin do
  it "functions as a plugin" do
    about = described_class.new.about
    expect(about.name).to eq("rubocop-gusto")
    expect(about.version).to eq(RuboCop::Gusto::VERSION)
    expect(about.homepage).to eq("https://github.com/Gusto/rubocop-gusto")
    expect(about.description).to eq("A collection of Gusto's standard RuboCop cops and rules.")
  end
end
