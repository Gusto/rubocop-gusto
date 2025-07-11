# frozen_string_literal: true

RSpec.describe RuboCop::Cop::InternalAffairs::AssignmentFirst, :config do
  context 'when hook is `on_send`' do
    context 'when first action is an assignment' do
      it do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x = 10
              ^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'handles single line assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x = 10
              ^^^^^^ Avoid placing an assignment as the first action in `on_send`.
            end
          end
        RUBY
      end

      it 'handles assignment by a method return value' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x = check_node_pattern(node)
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
            end
          end
        RUBY
      end

      it 'handles assignment by a method return value with long form module nesting' do
        expect_offense(<<~RUBY)
          module RuboCop
            module Cop
              class MyCop < Base
                def on_send(node)
                  x = check_node_pattern(node)
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
                  y = x
                end
              end
            end
          end
        RUBY
      end

      it 'handles instance variable assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              @x = 10
              ^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'handles class variable assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              @@x = 10
              ^^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'handles global variable assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              $x = 10
              ^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'handles multiple assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x, y = 1, 2
              ^^^^^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'handles or-assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x ||= 10
              ^^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'handles and-assignment' do
        expect_offense(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x &&= 10
              ^^^^^^^^ Avoid placing an assignment as the first action in `on_send`.
              do_something
            end
          end
        RUBY
      end

      it 'accepts assignment after an initial comparison (begin node)' do
        expect_no_offenses(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              x = 10 if could_be_true?
              y = 20
            end
          end
        RUBY
      end
    end

    context 'when first action is not an assignment' do
      it do
        expect_no_offenses(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              return unless matcher.match?(node)
              x = 10
              do_something
            end
          end
        RUBY
      end
    end

    context 'with empty method body' do
      it 'does not register nil nodes' do
        expect_no_offenses(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
            end
          end
        RUBY
      end

      it 'does not register empty parentheses' do
        expect_no_offenses(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              ()
            end
          end
        RUBY
      end
    end

    # TODO: if this becomes problematic, we can check that a guard clause or a node matcher is the first action
    context 'with initial method call' do
      it do
        expect_no_offenses(<<~RUBY)
          class MyCop < RuboCop::Cop::Base
            def on_send(node)
              calling_a_method
              x = 10
            end
          end
        RUBY
      end
    end
  end

  context 'with an unrelated method' do
    context 'when first action is an assignment' do
      it do
        expect_no_offenses(<<~RUBY)
          def my_method(node)
            x = 10
            do_something
          end
        RUBY
      end
    end
  end
end
