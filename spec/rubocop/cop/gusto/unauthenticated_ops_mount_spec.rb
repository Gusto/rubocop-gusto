# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::UnauthenticatedOpsMount, :config do
  it "registers an offense for a bare Sidekiq::Web mount with `at:`" do
    expect_offense(<<~RUBY)
      Rails.application.routes.draw do
        mount Sidekiq::Web, at: "/sidekiq"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Sidekiq::Web` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
      end
    RUBY
  end

  it "registers an offense for the hash-rocket form" do
    expect_offense(<<~RUBY)
      mount Karafka::Web::App => "/karafka"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Karafka::Web::App` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
    RUBY
  end

  it "registers an offense for a cbase-prefixed constant" do
    expect_offense(<<~RUBY)
      mount ::Gusto::Karafka::Engine, at: "/gusto_karafka"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Gusto::Karafka::Engine` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
    RUBY
  end

  it "registers an offense for an engine built with a method call on its constant" do
    expect_offense(<<~RUBY)
      mount Flipper::UI.app(Flipper) => "/flipper"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Flipper::UI` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
    RUBY
  end

  it "registers an offense for an engine built with a method call and mounted with `at:`" do
    expect_offense(<<~RUBY)
      mount Flipper::UI.app(Flipper), at: "/flipper"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Flipper::UI` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
    RUBY
  end

  it "registers an offense when a non-development environment check is the only gate" do
    expect_offense(<<~RUBY)
      if %w(staging production).include?(Gusto::Config.environment)
        mount EngineWithMiddleware.wrap(Sidekiq::Web, Rack::SessionAuth), at: "/sidekiq"
      else
        mount Sidekiq::Web, at: "/sidekiq"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Sidekiq::Web` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
      end
    RUBY
  end

  it "registers an offense in the non-development branch of a development check" do
    expect_offense(<<~RUBY)
      if Rails.env.development?
        mount Sidekiq::Web, at: "/sidekiq"
      else
        mount Karafka::Web::App, at: "/karafka"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Karafka::Web::App` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
      end
    RUBY
  end

  it "registers an offense in the body of `unless` a development check" do
    expect_offense(<<~RUBY)
      unless Rails.env.development?
        mount Sidekiq::Web, at: "/sidekiq"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Sidekiq::Web` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
      end
    RUBY
  end

  it "does not register an offense in a development-only `if` branch" do
    expect_no_offenses(<<~RUBY)
      if Gusto::Config.environment == "development"
        mount Karafka::Web::App, at: "/karafka"
        mount Sidekiq::Web, at: "/sidekiq"
      end
    RUBY
  end

  it "does not register an offense with the literal on the left of the comparison" do
    expect_no_offenses(<<~RUBY)
      mount Sidekiq::Web, at: "/sidekiq" if "development" == Rails.env
    RUBY
  end

  it "does not register an offense behind a `Rails.env.development?` modifier" do
    expect_no_offenses(<<~RUBY)
      mount ::Sidekiq::Web => "/sidekiq" if ::Rails.env.development?
    RUBY
  end

  it "does not register an offense in a development `elsif` branch" do
    expect_no_offenses(<<~RUBY)
      if %w(staging production).include?(Gusto::Config.environment)
        mount EngineWithMiddleware.wrap(Sidekiq::Web, Rack::SessionAuth), at: "/sidekiq"
      elsif Rails.env.development?
        mount Sidekiq::Web, at: "/sidekiq"
      end
    RUBY
  end

  it "does not register an offense in the `else` branch of `unless` a development check" do
    expect_no_offenses(<<~RUBY)
      unless Rails.env.development?
        mount EngineWithMiddleware.wrap(Sidekiq::Web, Rack::SessionAuth), at: "/sidekiq"
      else
        mount Sidekiq::Web, at: "/sidekiq"
      end
    RUBY
  end

  it "registers an offense inside a non-authenticating block such as `constraints`" do
    expect_offense(<<~RUBY)
      constraints(subdomain: "admin") do
        mount Sidekiq::Web, at: "/sidekiq"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Sidekiq::Web` inside an authentication block (`authenticate`/`authenticated`) or wrap it in authenticating middleware.
      end
    RUBY
  end

  it "does not register an offense inside an `authenticate` block" do
    expect_no_offenses(<<~RUBY)
      authenticate(:user, ->(u) { u.admin? }) do
        mount ::Sidekiq::Web => "sidekiq"
      end
    RUBY
  end

  it "does not register an offense inside an `authenticated` block nested in another block" do
    expect_no_offenses(<<~RUBY)
      Rails.application.routes.draw do
        authenticated nil, ->(user) { user.engineer? } do
          scope "/ops" do
            mount Sidekiq::Web, at: "/sidekiq"
          end
        end
      end
    RUBY
  end

  it "does not register an offense when the engine is wrapped in middleware" do
    expect_no_offenses(<<~RUBY)
      mount EngineWithMiddleware.wrap(Sidekiq::Web, Rack::SessionAuth), at: "/sidekiq"
    RUBY
  end

  it "does not register an offense for an engine not in the list" do
    expect_no_offenses(<<~RUBY)
      mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
    RUBY
  end

  it "does not register an offense for a mount with no arguments" do
    expect_no_offenses(<<~RUBY)
      mount
    RUBY
  end

  it "does not register an offense for `mount` with an explicit receiver" do
    expect_no_offenses(<<~RUBY)
      router.mount Sidekiq::Web, at: "/sidekiq"
    RUBY
  end

  it "does not register an offense for a safe-navigation `mount`" do
    expect_no_offenses(<<~RUBY)
      router&.mount Sidekiq::Web, at: "/sidekiq"
    RUBY
  end

  context "with configured engines and authentication methods" do
    let(:cop_config) { { "Engines" => ["Blazer::Engine"], "AuthenticationMethods" => ["require_engineer"] } }

    it "registers an offense for a configured engine" do
      expect_offense(<<~RUBY)
        mount Blazer::Engine, at: "/blazer"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mount `Blazer::Engine` inside an authentication block (`require_engineer`) or wrap it in authenticating middleware.
      RUBY
    end

    it "does not register an offense inside a configured authentication block" do
      expect_no_offenses(<<~RUBY)
        require_engineer do
          mount Blazer::Engine, at: "/blazer"
        end
      RUBY
    end

    it "does not register an offense for an engine that is no longer configured" do
      expect_no_offenses(<<~RUBY)
        mount Sidekiq::Web, at: "/sidekiq"
      RUBY
    end
  end
end
