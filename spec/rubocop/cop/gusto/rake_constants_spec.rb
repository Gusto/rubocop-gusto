# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::RakeConstants, :config do
  context 'when defining a class inside a task' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        task :foo do
          class C
          ^^^^^^^ Do not define a constant in rake file, because they are sometimes `load`ed, instead of `require`d which can lead to warnings about redefining constants
          end
        end
      RUBY
    end
  end

  context 'when defining a module inside a namespace' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        namespace :foo do
          module M
          ^^^^^^^^ Do not define a constant in rake file, because they are sometimes `load`ed, instead of `require`d which can lead to warnings about redefining constants
          end
        end
      RUBY
    end
  end

  context 'when defining a class at the top level' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class C
        end
        task :foo do
        end
      RUBY
    end
  end

  context 'when defining a module at the top level' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        module M
        end
        namespace :foo do
        end
      RUBY
    end
  end

  context 'when defining a constant before a task' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        CONST = 1
        task :foo do
        end
      RUBY
    end
  end

  context 'when defining a constant inside a task' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        task :foo do
          CONST = 1
          ^^^^^^^^^ Do not define a constant in rake file, because they are sometimes `load`ed, instead of `require`d which can lead to warnings about redefining constants
        end
      RUBY
    end
  end

  context 'when defining a constant inside a namespace' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        namespace :foo do
          CONST = 1
          ^^^^^^^^^ Do not define a constant in rake file, because they are sometimes `load`ed, instead of `require`d which can lead to warnings about redefining constants
        end
      RUBY
    end
  end

  context 'when defining a constant outside a task or namespace' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        CONST = 1
      RUBY
    end
  end
end
