# frozen_string_literal: true

require "open3"

RSpec.describe "Gusto-only cop loading" do
  it "registers the logging cops without loading the full plugin configuration" do
    output, error, status = Open3.capture3(
      RbConfig.ruby, "-Ilib", "-rrubocop/cop/gusto/all", "-e",
      'puts RuboCop::Cop::Registry.global.names.grep(%r{\AGusto/Logging/}).sort'
    )

    expect(status.success?).to be(true), error
    expect(output.lines.map(&:strip)).to eq(
      %w(
        Gusto/Logging/ExceptionMessage
        Gusto/Logging/PiiAccessor
        Gusto/Logging/RawParams
        Gusto/Logging/ResponseBody
        Gusto/Logging/SerializedObject
      )
    )
  end
end
