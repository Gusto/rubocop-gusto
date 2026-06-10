# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::NoPerformAsyncStub, :config do
  context "when not a spec file" do
    let(:source) do
      <<~RUBY
        Foo.receive(:perform_async)
        Foo.have_received(:perform_async)
        allow(Foo).to receive(:perform_async)
        expect(Foo).to_not receive(:perform_async)
      RUBY
    end

    it { expect_no_offenses source, "example.rb" }
  end

  context "when not stubbing perform_async" do
    let(:source) do
      <<~RUBY
        allow(Foo).to receive(:new)
      RUBY
    end

    it { expect_no_offenses source, "example_spec.rb" }
  end

  # That context is required only to please coverage reporter
  context "when receive(:perform_async) is the parse root" do
    it "autocorrects by appending and_call_original" do
      expect_offense(<<~RUBY, "example_spec.rb")
        receive(:perform_async)
        ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`.
      RUBY

      expect_correction(<<~RUBY)
        receive(:perform_async).and_call_original
      RUBY
    end
  end

  context "when using allow" do
    context "without arguments" do
      it "flags receive(:perform_async) and autocorrects with and_call_original" do
        expect_offense(<<~RUBY, "example_spec.rb")
          allow(Foo).to receive(:perform_async)
                        ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`.
        RUBY

        expect_correction(<<~RUBY)
          allow(Foo).to receive(:perform_async).and_call_original
        RUBY
      end
    end

    context "with arguments" do
      it "flags receive(:perform_async).with and appends and_call_original after the with chain" do
        expect_offense(<<~RUBY, "foo_spec.rb")
          allow(Foo).to receive(:perform_async).with('bar')
                        ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`.
        RUBY

        expect_correction(<<~RUBY)
          allow(Foo).to receive(:perform_async).with('bar').and_call_original
        RUBY
      end
    end

    context "when chained with and_call_original" do
      let(:source) do
        <<~RUBY
          allow(Foo).to receive(:perform_async).and_call_original
        RUBY
      end

      it { expect_no_offenses(source, "example_spec.rb") }
    end

    context "when chained with with() and and_call_original" do
      let(:source) do
        <<~RUBY
          allow(Foo).to receive(:perform_async).with('bar').and_call_original
        RUBY
      end

      it { expect_no_offenses(source, "example_spec.rb") }
    end
  end

  context "when using expect" do
    context "without arguments" do
      it "flags receive(:perform_async) and autocorrects with and_call_original" do
        expect_offense(<<~RUBY, "example_spec.rb")
          expect(Foo).to receive(:perform_async)
                         ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`.
        RUBY

        expect_correction(<<~RUBY)
          expect(Foo).to receive(:perform_async).and_call_original
        RUBY
      end
    end

    context "with arguments and modifiers" do
      it "flags receive(:perform_async).with and appends and_call_original after the with chain" do
        expect_offense(<<~RUBY, "foo_spec.rb")
          expect(Foo).to receive(:perform_async).once.with('bar')
                         ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async` or add `.and_call_original`.
        RUBY

        expect_correction(<<~RUBY)
          expect(Foo).to receive(:perform_async).once.with('bar').and_call_original
        RUBY
      end
    end

    context "when chained with and_call_original" do
      let(:source) do
        <<~RUBY
          expect(ResearchAndDevelopmentCredit::Jobs::CorrectOverdrawnCredit).to receive(:perform_async).and_call_original
        RUBY
      end

      it { expect_no_offenses(source, "example_spec.rb") }
    end

    context "when expect ... not_to" do
      it "flags not_to receive(:perform_async) without autocorrect" do
        expect_offense(<<~RUBY, "foo_spec.rb")
          expect(Foo).not_to receive(:perform_async)
                             ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async`.
        RUBY

        expect_no_corrections
      end
    end

    context "when expect ... to_not" do
      it "flags to_not receive(:perform_async) without autocorrect" do
        expect_offense(<<~RUBY, "foo_spec.rb")
          expect(Foo).to_not receive(:perform_async)
                             ^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async`.
        RUBY

        expect_no_corrections
      end
    end

    context "when using have_received" do
      it "flags have_received(:perform_async).with and does not autocorrect" do
        expect_offense(<<~RUBY, "example_spec.rb")
          expect(Foo).to have_received(:perform_async).with(1)
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Prefer checking enqueued jobs over stubbing `perform_async`.
        RUBY

        expect_no_corrections
      end
    end
  end
end
