# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "rspec/core"
require "rubocop-gusto"
require "rubocop/cop/internal_affairs"

# Require supporting files exposed for testing.
require "rubocop/rspec/support"

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.include RuboCop::RSpec::ExpectOffense

  config.expect_with(:rspec) do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect # Disable `should`
  end

  config.mock_with(:rspec) do |mocks|
    mocks.syntax = :expect # Disable `should_receive` and `stub`
    mocks.verify_partial_doubles = true
  end
end
