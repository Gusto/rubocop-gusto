# frozen_string_literal: true

require "rubocop"
require_relative "../../gusto"
require_relative "../../gusto/version"

Dir.glob("#{__dir__}/*.rb").sort.each { |f| require f unless f == __FILE__ }
