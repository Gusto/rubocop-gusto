# frozen_string_literal: true

require "tempfile"

RSpec.describe RuboCop::Cop::Gusto::UnreferencedLet, :config do
  # Keep the file-detection examples independent of whatever `spec/support/**` happens to exist
  # in the working directory; the framework-contract behavior is exercised explicitly below.
  before { described_class.instance_variable_set(:@framework_let_names, Set.new) }

  it "flags and removes unreferenced lazy lets" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:unused) { create(:thing) }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.
        let(:also_unused) { create(:other) }
        ^^^ Remove unreferenced `let(:also_unused)` -- its name is never used, so the block never runs.

        it { expect(1).to eq(1) }
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe Thing do

        it { expect(1).to eq(1) }
      end
    RUBY
  end

  it "removes a preceding Sorbet signature along with the let" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        sig { returns(Integer) }
        let(:unused) { 1 }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.

        it { expect(1).to eq(1) }
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe Thing do
        it { expect(1).to eq(1) }
      end
    RUBY
  end

  it "flags an unreferenced let written as a numbered-parameter block" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:unused) { create(_1) }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe Thing do
      end
    RUBY
  end

  it "removes an explanatory comment attached directly above the let" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:kept) { 1 }

        # allows us to see the output
        let(:unused) { false }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.

        it { expect(kept).to eq(1) }
      end
    RUBY

    # The comment + let are removed, and the now-duplicate trailing blank is consumed so no
    # stray blank is left behind.
    expect_correction(<<~RUBY)
      RSpec.describe Thing do
        let(:kept) { 1 }

        it { expect(kept).to eq(1) }
      end
    RUBY
  end

  it "consumes a trailing blank at a block-body edge but keeps the blank after a final let" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:kept) { 1 }
        let(:unused) { 2 }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.

        it { expect(kept).to eq(1) }
      end
    RUBY

    # `let(:kept)` precedes the removal, so the blank after it (the final-let separator) stays.
    expect_correction(<<~RUBY)
      RSpec.describe Thing do
        let(:kept) { 1 }

        it { expect(kept).to eq(1) }
      end
    RUBY
  end

  it "does not absorb a rubocop directive comment above the let" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        # rubocop:disable Style/Something
        let(:unused) { false }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.
        # rubocop:enable Style/Something
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe Thing do
        # rubocop:disable Style/Something
        # rubocop:enable Style/Something
      end
    RUBY
  end

  it "does not flag an eager let! (out of scope)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let!(:unused) { create(:thing) }

        it { expect(1).to eq(1) }
      end
    RUBY
  end

  it "does not flag a referenced lazy let" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:thing) { create(:thing) }

        it { expect(thing).to be_present }
      end
    RUBY
  end

  it "does not flag a let referenced via dynamic dispatch" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:thing) { create(:thing) }

        it { expect(send(:thing)).to be_present }
      end
    RUBY
  end

  it "does not flag a let referenced only as a symbol literal (data-table dispatch)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:special_tax) { build(:tax) }

        it "dispatches by name" do
          [[:special_tax, :pending]].each do |name, _state|
            expect(send(name)).to be_present
          end
        end
      end
    RUBY
  end

  it "does not flag a let referenced only as a string literal (string dispatch)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:special_tax) { build(:tax) }

        it { expect(send("special_tax")).to be_present }
      end
    RUBY
  end

  it "skips every let in a file that dispatches through an interpolated string" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:expected_dental_value) { 1 }

        it "dispatches by interpolated name" do
          %w(dental vision).each do |type|
            expect(described_class.for(type)).to eq(send("expected_\#{type}_value"))
          end
        end
      end
    RUBY
  end

  it "still flags a dead let in a file whose only send target is a static string" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:unused) { create(:thing) }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.

        it { expect(send("other")).to be_present }
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe Thing do
        it { expect(send("other")).to be_present }
      end
    RUBY
  end

  it "does not flag a name defined by more than one let/let! (override / super chain)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:value) { 1 }

        context "nested" do
          let!(:value) { 2 }

          it { expect(1).to eq(1) }
        end
      end
    RUBY
  end

  it "does not flag a let overridden by a subject of the same name (super chain)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:described) { build(:thing) }

        context "when active" do
          subject(:described) { super().tap(&:activate) }

          it { is_expected.to be_active }
        end
      end
    RUBY
  end

  it "does not flag an unreferenced subject (only lazy let is in scope)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        subject(:unused) { build(:thing) }

        it { expect(1).to eq(1) }
      end
    RUBY
  end

  it "skips every let in a file that consumes shared examples" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:unused) { create(:thing) }

        it_behaves_like "a thing"
      end
    RUBY
  end

  it "skips a let declared inside a shared example definition" do
    expect_no_offenses(<<~RUBY)
      RSpec.shared_examples "a thing" do
        let(:unused_inner) { create(:thing) }

        it { expect(1).to eq(1) }
      end
    RUBY
  end

  it "still flags an unreferenced let declared outside a shared example definition" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:unused) { create(:thing) }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.

        shared_examples "a thing" do
          it { expect(1).to eq(1) }
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe Thing do
        shared_examples "a thing" do
          it { expect(1).to eq(1) }
        end
      end
    RUBY
  end

  it "ignores let declarations without a symbol name" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        name = :dynamic
        let(name) { create(:thing) }
        let { create(:thing) }
      end
    RUBY
  end

  it "ignores a let call with no block" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:unused)
      end
    RUBY
  end

  it "ignores a let-like call with an explicit receiver" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        config.let(:unused) { create(:thing) }
      end
    RUBY
  end

  it "does not flag a let that overrides a framework contract defined in spec/support" do
    described_class.instance_variable_set(:@framework_let_names, Set[:query])

    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing, subgraph: :foo do
        let(:query) { "mutation { ... }" }

        it { is_expected.to be_present }
      end
    RUBY
  end

  describe "framework let-name discovery" do
    it "memoizes the scanned name set" do
      described_class.instance_variable_set(:@framework_let_names, nil)

      first = described_class.framework_let_names
      second = described_class.framework_let_names

      expect(first).to be_a(Set).and equal(second)
    end

    it "extracts let, let! and subject names from source" do
      names = described_class.extract_let_names(<<~RUBY, Set.new)
        let(:foo) { 1 }
        let! :bar do
          2
        end
        subject(:baz) { 3 }
        plain_method(:not_a_let)
      RUBY

      expect(names).to contain_exactly(:foo, :bar, :baz)
    end

    it "scans paths for let names, tolerating unreadable files" do
      file = Tempfile.new(["support", ".rb"])
      file.write("let(:harness_thing) { 1 }")
      file.close

      names = described_class.scan_framework_let_names([file.path, "/no/such/support/file.rb"])

      expect(names).to contain_exactly(:harness_thing)
    ensure
      file&.close!
    end

    it "returns an empty string when a file cannot be read" do
      expect(described_class.read_source("/no/such/support/file.rb")).to eq("")
    end
  end

  describe "support-file enumeration" do
    it "selects spec/support .rb paths from the git index" do
      status = instance_double(Process::Status, success?: true)
      output = ["packs/a/spec/support/helper.rb", "lib/y.rb", "spec/support/root.rb", "spec/supportive/no.rb", ""].join("\x0")
      allow(Open3).to receive(:capture2).with("git", "ls-files", "-z").and_return([output, status])

      expect(described_class.git_tracked_support_files)
        .to contain_exactly("packs/a/spec/support/helper.rb", "spec/support/root.rb")
    end

    it "returns nil when git ls-files exits non-zero" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture2).and_return(["", status])

      expect(described_class.git_tracked_support_files).to be_nil
    end

    it "returns nil when git is unavailable" do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)

      expect(described_class.git_tracked_support_files).to be_nil
    end

    it "uses the git-tracked files when available" do
      allow(described_class).to receive(:git_tracked_support_files).and_return(["spec/support/tracked.rb"])

      expect(described_class.support_file_paths).to eq(["spec/support/tracked.rb"])
    end

    it "falls back to Dir.glob when git tracking is unavailable" do
      allow(described_class).to receive(:git_tracked_support_files).and_return(nil)
      allow(Dir).to receive(:glob).with(described_class::SUPPORT_FILES_GLOB).and_return(["spec/support/from_glob.rb"])

      expect(described_class.support_file_paths).to eq(["spec/support/from_glob.rb"])
    end
  end
end
