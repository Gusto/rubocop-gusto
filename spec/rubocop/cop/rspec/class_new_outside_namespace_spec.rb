# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      RSpec.describe ClassNewOutsideNamespace do
        describe "no offenses" do
          context "when Class.new is inside a module" do
            let(:source) do
              <<~RUBY
                module MyModule
                  let(:dummy_class) do
                    Class.new do
                      def match?(request)
                        42
                      end
                    end
                  end
                end
              RUBY
            end

            it { expect_no_offenses source, "example_spec.rb" }
          end

          context "when Class.new is inside a class" do
            let(:source) do
              <<~RUBY
                class MyClass
                  let(:dummy_class) do
                    Class.new do
                      def match?(request)
                        42
                      end
                    end
                  end
                end
              RUBY
            end

            it { expect_no_offenses source, "example_spec.rb" }
          end

          context "when Class.new is inside nested module and class" do
            let(:source) do
              <<~RUBY
                module Outer
                  class Inner
                    let(:dummy_class) do
                      Class.new do
                        def match?(request)
                          42
                        end
                      end
                    end
                  end
                end
              RUBY
            end

            it { expect_no_offenses source, "example_spec.rb" }
          end

          context "when using a proper class definition" do
            let(:source) do
              <<~RUBY
                module MyModule
                  class DummyClass
                    def match?(request)
                      42
                    end
                  end
                end

                let(:dummy_class) { MyModule::DummyClass }
              RUBY
            end

            it { expect_no_offenses source, "example_spec.rb" }
          end

          context "when not using Class.new" do
            let(:source) do
              <<~RUBY
                let(:result) do
                  SomeClass.new do
                    puts "hello"
                  end
                end
              RUBY
            end

            it { expect_no_offenses source, "example_spec.rb" }
          end
        end

        describe "offenses" do
          context "when Class.new is at root scope" do
            it "flags Class.new with a block" do
              source = <<~RUBY
                let(:dummy_class) do
                  Class.new do
                  ^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                    def match?(request)
                      42
                    end
                  end
                end
              RUBY
              expect_offense source, "example_spec.rb"
            end
          end

          context "when Class.new is in RSpec.describe block (which is not a class/module)" do
            it "flags Class.new" do
              source = <<~RUBY
                RSpec.describe SomeClass do
                  let(:dummy_parent_class) do
                    Class.new do
                    ^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                      def find_collection(_options)
                        Employee.all
                      end

                      def resource
                        Employee.first
                      end
                    end
                  end
                end
              RUBY
              expect_offense source, "example_spec.rb"
            end
          end

          context "when Class.new is in a context block" do
            it "flags Class.new" do
              source = <<~RUBY
                RSpec.describe SomeClass do
                  context 'with a dummy class' do
                    let(:dummy_class) do
                      Class.new do
                      ^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                        def match?(request)
                          true
                        end
                      end
                    end
                  end
                end
              RUBY
              expect_offense source, "example_spec.rb"
            end
          end

          context "when Class.new is in a before block" do
            it "flags Class.new" do
              source = <<~RUBY
                RSpec.describe SomeClass do
                  before do
                    @dummy_class = Class.new do
                                   ^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                      def match?(request)
                        true
                      end
                    end
                  end
                end
              RUBY
              expect_offense source, "example_spec.rb"
            end
          end

          context "when Class.new has arguments but is still outside a namespace" do
            it "flags Class.new with superclass argument" do
              source = <<~RUBY
                let(:dummy_class) do
                  Class.new(BaseClass) do
                  ^^^^^^^^^^^^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                    def match?(request)
                      42
                    end
                  end
                end
              RUBY
              expect_offense source, "example_spec.rb"
            end
          end

          context "when multiple Class.new calls at root scope" do
            it "flags both Class.new calls" do
              source = <<~RUBY
                let(:dummy_class_a) do
                  Class.new do
                  ^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                    def method_a
                      1
                    end
                  end
                end

                let(:dummy_class_b) do
                  Class.new do
                  ^^^^^^^^^ Do not use Class.new outside of a class/module declaration. Define a proper class inside a module/class to avoid Sorbet type errors where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609
                    def method_b
                      2
                    end
                  end
                end
              RUBY
              expect_offense source, "example_spec.rb"
            end
          end
        end
      end
    end
  end
end
