# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::SidekiqParams, :config do
  it "registers an offense when perform method has keyword arguments" do
    expect_offense(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        def perform(foo:, bar: 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^^ Sidekiq perform methods cannot take keyword arguments
          # do something
        end
      end
    RUBY
  end

  it "registers an offense when perform method has optional keyword arguments" do
    expect_offense(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        def perform(foo, bar: 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^ Sidekiq perform methods cannot take keyword arguments
          # do something
        end
      end
    RUBY
  end

  it "does not register an offense when perform method has only positional arguments" do
    expect_no_offenses(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        def perform(foo, bar)
          # do something
        end
      end
    RUBY
  end

  it "does not register an offense when perform method has no arguments" do
    expect_no_offenses(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        def perform
          # do something
        end
      end
    RUBY
  end

  it "does not register an offense for non-perform methods with keyword arguments" do
    expect_no_offenses(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        def some_method(foo:, bar: 1)
          # do something
        end

        def perform(foo, bar)
          # do something
        end
      end
    RUBY
  end
end
