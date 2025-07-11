# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RuboCop::Cop::Gusto::FactoryClassesOrModules, :config do
  it 'allows factory definitions' do
    expect_no_offenses <<~RUBY
      FactoryBot.define do
        factory(:address, class: 'RemoteModels::Address') do
          id { Faker::Number.number(digits: 12).to_i }
          street_1 { Faker::Address.street_address }
        end
      end
    RUBY
  end

  it 'does not allow classes or modules' do
    expect_offense <<~RUBY
      FactoryBot.define do
      end

      class Foo
      ^^^^^^^^^ Do not define modules or classes in factory directories - they break reloading
      end

      module Bar
      ^^^^^^^^^^ Do not define modules or classes in factory directories - they break reloading
      end
    RUBY
  end
end
