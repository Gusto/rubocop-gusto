# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::DatadogConstant, :config do
  it 'has an offense when using Datadog top-module constant' do
    expect_offense(<<-RUBY)
      ::Datadog::Tracing.active_trace&.keep!
      ^^^^^^^^^ [...]
    RUBY
  end

  it 'has an offense when using Datadog constant' do
    expect_offense(<<-RUBY)
      Datadog::Tracing::Correlation::Identifier
      ^^^^^^^ [...]
    RUBY
  end
end
