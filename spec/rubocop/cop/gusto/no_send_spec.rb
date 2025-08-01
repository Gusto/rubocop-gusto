# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::NoSend, :config do
  context "when using send" do
    let(:source) do
      <<~TEXT
        foo.send(:bar)
      TEXT
    end

    it { expect_no_offenses source }
  end

  context "when using stand alone send" do
    let(:source) do
      <<~TEXT
        send(:bar)
      TEXT
    end

    it { expect_no_offenses source }
  end

  context "when using public_send" do
    let(:source) do
      <<~TEXT
        Foo.public_send(:bar)
      TEXT
    end

    it { expect_no_offenses source }
  end

  context "when using __send__" do
    let(:source) do
      <<~TEXT
        Foo.__send__(:bar)
        ^^^^^^^^^^^^^^^^^^ Do not call a private method via `__send__`.
      TEXT
    end

    it { expect_offense source }
  end

  context "when using standalone __send__" do
    let(:source) do
      <<~TEXT
        __send__(:bar)
        ^^^^^^^^^^^^^^ Do not call a private method via `__send__`.
      TEXT
    end

    it { expect_offense source }
  end

  context "when using safe navigation with __send__" do
    let(:source) do
      <<~TEXT
        foo&.__send__(:bar)
        ^^^^^^^^^^^^^^^^^^^ Do not call a private method via `__send__`.
      TEXT
    end

    it { expect_offense source }
  end

  context "when part of a chain" do
    let(:source) do
      <<~TEXT
        Foo.new.__send__(:bar)
        ^^^^^^^^^^^^^^^^^^^^^^ Do not call a private method via `__send__`.
      TEXT
    end

    it { expect_offense source }
  end

  context "when __send__ is a symbol" do
    let(:source) do
      <<~TEXT
        Foo.bar(:__send__)
      TEXT
    end

    it { expect_no_offenses source }
  end
end
