# frozen_string_literal: true

require "rubocop"
require "rubocop-rspec"

require_relative "rubocop/gusto"
require_relative "rubocop/gusto/version"
require_relative "rubocop/gusto/plugin"

# Require all cops
Dir.glob(File.join(File.dirname(__FILE__), "rubocop/cop/**/*.rb")).each do |file|
  require file
end
