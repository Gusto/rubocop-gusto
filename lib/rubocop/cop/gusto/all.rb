# frozen_string_literal: true

require "rubocop"
require_relative "../../gusto"
require_relative "../../gusto/version"

Dir.glob("#{__dir__}/*.rb").sort.each do |f|
  next if f == __FILE__
  next if f.end_with?("unreferenced_let.rb") && RUBY_VERSION < "3.4"

  require f
end
