# frozen_string_literal: true

RSpec.describe(RuboCop::Cop::Gusto::PerformClassMethod, :config) do
  it("registers an offense for class level `perform` method") do
    expect_offense(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        MY_CONSTANT = 1

        def self.perform
        ^^^^^^^^^^^^^^^^ Class-level `perform` method is being defined. Did you mean to use an instance method?
        end
      end
    RUBY
  end

  it("registers an offense for class << self `perform` method") do
    expect_offense(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        MY_CONSTANT = 1

        class << self
          def perform
          ^^^^^^^^^^^ Class-level `perform` method is being defined. Did you mean to use an instance method?
          end
        end
      end
    RUBY
  end

  it("does not register an offense for class methods not named `perform`") do
    expect_no_offenses(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        MY_CONSTANT = 1

        def self.foo
        end
      end
    RUBY
  end

  it("does not register an offense for instance level `perform` method") do
    expect_no_offenses(<<~RUBY)
      class MyWorker
        include Sidekiq::Worker

        MY_CONSTANT = 1

        def perform
        end
      end
    RUBY
  end

  it("does not register an offense for non-Sidekiq workers") do
    expect_no_offenses(<<~RUBY)
      class NotAWorker
        include NotSidekiq

        MY_CONSTANT = 1

        def self.perform
        end
      end
    RUBY
  end

  it("does not register an offense for namespaced non-Sidekiq workers") do
    expect_no_offenses(<<~RUBY)
      class MyNamespace::NotAWorker
        def self.perform
        end
      end
    RUBY
  end

  it("does not register an offense for non-Sidekiq workers with class << self") do
    expect_no_offenses(<<~RUBY)
      class NotAWorker
        include NotSidekiq

        MY_CONSTANT = 1

        class << self
          def perform
          end
        end
      end
    RUBY
  end

  context("when `WorkerModules` config is set") do
    let(:cop_config) { { "WorkerModules" => ["Gusto::Workers::Within1Hour"] } }

    it("registers an offense when specified modules are included") do
      expect_offense(<<~RUBY)
        class MyWorker
          include Gusto::Workers::Within1Hour

          MY_CONSTANT = 1

          def self.perform
          ^^^^^^^^^^^^^^^^ Class-level `perform` method is being defined. Did you mean to use an instance method?
          end
        end
      RUBY
    end
  end

  it("does not register an offense when include argument is not a constant") do
    expect_no_offenses(<<~RUBY)
      class MyWorker
        include send(:Sidekiq).const_get(:Worker)

        def self.perform
        end
      end
    RUBY
  end
end
