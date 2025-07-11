# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::ToplevelConstants, :config do
  let(:filepath) { 'lib/foo/bar.rb' }

  describe 'checking for toplevel constants' do
    context 'when a top-level constant is found' do
      let(:filepath) { 'lib/foo/bar.rb' }

      it('registers an offense') do
        expect_offense(<<~RUBY, filepath)
          # frozen_string_literal: true

          FOO = 'bar'
          ^^^^^^^^^^^ Top-level constants should be defined in an initializer.[...]

          class MyClass
          end
        RUBY
      end
    end

    context 'when a top-level constant is not found' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY, filepath)
          module Foo
            class Bar
              BAR = 'baz'
            end
          end
        RUBY
      end
    end

    context 'when a nested constant is defined as a one-liner' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY, filepath)
          MyModule::MY_CONSTANT = 10
        RUBY
      end
    end

    context "when a top-level constant isn't found in a nested module" do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY, filepath)
          # frozen_string_literal: true

          module Quidditch
            module Balls
              class Snitch
                include Behaviors::Darting
                include Behaviors::Flying
                include Behaviors::Hovering

                COLOR = 'gold'
              end
            end
          end
        RUBY
      end
    end
  end
end
