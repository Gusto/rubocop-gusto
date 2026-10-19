# frozen_string_literal: true

require "tempfile"

RSpec.describe RuboCop::Cop::Gusto::UnreferencedLet, :config do
  # Keep the file-detection examples independent of whatever `spec/support/**` happens to exist
  # in the working directory; the framework-contract behavior is exercised explicitly below.
  before do
    described_class.instance_variable_set(:@framework_let_names, Set.new)
    described_class.instance_variable_set(:@support_files, [])
    %i(@support_index @support_reads @harness_reads @local_context_reads).each { |ivar| described_class.instance_variable_set(ivar, nil) }
  end

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

  it "does not flag `let(:cop_config)` (a rubocop-rspec framework contract)" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe RuboCop::Cop::Gusto::SomeCop, :config do
        let(:cop_config) { { "Enabled" => true } }

        it { expect(1).to eq(1) }
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

  it "does not flag a let referenced only inside a heredoc body" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Thing do
        let(:cutoff_date) { Date.today }
        let(:query) do
          <<~SQL
            SELECT * FROM things WHERE created_at < cutoff_date
          SQL
        end

        it { expect(described_class.run(query)).to be_present }
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

  it "does not crash on a let whose block contains an invalid-UTF-8 string literal" do
    expect_offense(<<~'RUBY')
      RSpec.describe Thing do
        let(:unused) { String.new("\xc2invalid", encoding: "UTF-8") }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.

        it { expect(1).to eq(1) }
      end
    RUBY

    expect_correction(<<~'RUBY')
      RSpec.describe Thing do
        it { expect(1).to eq(1) }
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

  context "with Cascade" do
    let(:cop_config) { { "Cascade" => true } }

    it "flags a let read only by another unreferenced let" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:unused) { build(:thing, owner: owner) }
          ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.
          let(:owner) { create(:user) }
          ^^^ Remove unreferenced `let(:owner)` -- its name is never used, so the block never runs.

          it { expect(1).to eq(1) }
        end
      RUBY
    end

    it "flags a let that names itself only inside its own block" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:status) { { status: "ok" } }
          ^^^ Remove unreferenced `let(:status)` -- its name is never used, so the block never runs.

          it { expect(1).to eq(1) }
        end
      RUBY
    end

    it "does not flag a let read by a live let" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:thing) { build(:thing, owner: owner) }
          let(:owner) { create(:user) }

          it { expect(thing).to be_present }
        end
      RUBY
    end
  end

  it "flags only the outer let of a cascade without Cascade" do
    expect_offense(<<~RUBY)
      RSpec.describe Thing do
        let(:unused) { build(:thing, owner: owner) }
        ^^^ Remove unreferenced `let(:unused)` -- its name is never used, so the block never runs.
        let(:owner) { create(:user) }

        it { expect(1).to eq(1) }
      end
    RUBY
  end

  context "with PerExampleGroup" do
    let(:cop_config) { { "PerExampleGroup" => true } }
    let(:support_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(support_dir) }

    def support_file(name, source)
      FileUtils.mkdir_p(File.join(support_dir, "spec/support"))
      File.write(File.join(support_dir, "spec/support", name), source)
      described_class.instance_variable_set(:@support_files, Dir.glob(File.join(support_dir, "spec/support/*.rb")))
    end

    it "flags a let read only in a sibling group" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "when active" do
            let(:origin) { :web }
            ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end

          context "when inactive" do
            it { expect(described_class.new(origin)).to be_present }
          end
        end
      RUBY
    end

    it "flags each dead definition of a name defined in several groups" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "by email" do
            let(:delivery_method) { :email }
            ^^^ Remove unreferenced `let(:delivery_method)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end

          context "by sms" do
            let(:delivery_method) { :sms }
            ^^^ Remove unreferenced `let(:delivery_method)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end
        end
      RUBY
    end

    it "does not flag a let read in a nested group" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          context "when active" do
            it { expect(described_class.new(origin)).to be_present }
          end
        end
      RUBY
    end

    it "does not flag a default read by its own group's hook and overridden by every child" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          before { described_class.configure(origin) }

          context "from the api" do
            let(:origin) { :api }

            it { expect(1).to eq(1) }
          end
        end
      RUBY
    end

    it "does not flag a let overriding an enclosing let!" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let!(:record) { create(:thing) }

          context "when archived" do
            let(:record) { create(:thing, :archived) }

            it { expect(1).to eq(1) }
          end
        end
      RUBY
    end

    it "does not flag a let sharing its name with a subject" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          context "when active" do
            let(:described) { build(:thing) }

            it { expect(1).to eq(1) }
          end

          context "when inactive" do
            subject(:described) { build(:thing) }

            it { is_expected.to be_present }
          end
        end
      RUBY
    end

    it "does not flag a let read through defined?" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          context "when active" do
            let(:origin) { :web }

            it { expect(defined?(origin)).to be_truthy }
          end
        end
      RUBY
    end

    it "does not flag a let read by a shared group defined in the file" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          shared_examples "a thing" do
            it { expect(origin).to be_present }
          end

          context "when active" do
            let(:origin) { :web }

            it_behaves_like "a thing"
          end
        end
      RUBY
    end

    it "does not flag a let in the lineage of a group it cannot resolve" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          it_behaves_like "a thing defined elsewhere"

          context "when shared by constant" do
            let(:channel) { :email }

            it_behaves_like Things::SharedExamples
          end
        end
      RUBY
    end

    it "flags a let whose lineage includes nothing even though a sibling group does" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "when active" do
            let(:origin) { :web }
            ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end

          context "when shared" do
            it_behaves_like "a thing defined elsewhere"
          end
        end
      RUBY
    end

    it "does not flag a let in an include_context block read by a sibling group" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          include_context "a thing defined elsewhere" do
            let(:origin) { :web }
          end

          context "when active" do
            it { expect(origin).to be_present }
          end
        end
      RUBY
    end

    it "does not flag a let in the lineage of a local-context include" do
      other_cops["RSpec"]["Language"]["Includes"]["Context"] << "include_local_context"
      support_file("local_context.rb", 'RSpec.shared_context("things") { it { expect(1).to eq(1) } }')

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          include_local_context :things

          let(:origin) { :web }
        end
      RUBY
    end

    it "flags a let that an included support group cannot read" do
      support_file("a_thing.rb", <<~RUBY)
        RSpec.shared_examples "a thing" do
          it { expect(described_class.new(channel)).to be_present }
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:channel) { :email }
          let(:origin) { :web }
          ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

          it_behaves_like "a thing"
          it_behaves_like "a thing" do
            let(:priority) { :high }
            ^^^ Remove unreferenced `let(:priority)` -- its name is never used, so the block never runs.
          end
        end
      RUBY
    end

    it "follows the groups an included support group includes" do
      support_file("a_thing.rb", 'RSpec.shared_examples("a thing") { include_examples "a channel" }')
      support_file("a_channel.rb", 'RSpec.shared_examples("a channel") { it { expect(channel).to be_present }; include_examples "a thing" }')

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:channel) { :email }
          let(:origin) { :web }
          ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

          it_behaves_like "a thing"
        end
      RUBY
    end

    it "does not flag a let when an included support group includes a group it cannot resolve" do
      support_file("a_thing.rb", 'RSpec.shared_examples("a thing") { include_examples "a channel defined elsewhere" }')

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          it_behaves_like "a thing"
        end
      RUBY
    end

    it "does not flag a let when an included support group includes another by a name it cannot resolve" do
      support_file("a_thing.rb", 'RSpec.shared_examples("a thing") { |name| it_behaves_like name }')

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          it_behaves_like "a thing"
        end
      RUBY
    end

    it "does not flag a let when an included support group dispatches through a name it computes" do
      support_file("a_thing.rb", <<~'RUBY')
        RSpec.shared_examples "a thing" do |attribute|
          it { expect(send(attribute.to_s.sub("x", "y"))).to be_present }
        end
      RUBY

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          it_behaves_like "a thing", :channel
        end
      RUBY
    end

    it "flags only the lets an included support group's interpolated dispatch could match" do
      support_file("a_thing.rb", <<~'RUBY')
        RSpec.shared_examples "a thing" do |attribute|
          it { expect(public_send(attribute)).to be_present }
          it { expect(self.try("#{attribute}_override")).to be_nil }
          it { expect(record.public_send("#{attribute}_value")).to be_present }
          %w(body html).each do |part|
            it { expect(try("#{part}_#{attribute}")).to be_nil }
          end
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:channel_override) { :web }
          let(:html_footer) { "footer" }
          let(:text_footer) { "footer" }
          ^^^ Remove unreferenced `let(:text_footer)` -- its name is never used, so the block never runs.
          let(:channel_value) { 1 }
          ^^^ Remove unreferenced `let(:channel_value)` -- its name is never used, so the block never runs.

          it_behaves_like "a thing", :channel
        end
      RUBY
    end

    it "judges reflective calls in the spec by the names they could build, in their lineage" do
      expect_offense(<<~'RUBY')
        RSpec.describe Thing do
          context "with dispatch" do
            let(:expected_dental_value) { 1 }
            let(:expected_count) { 2 }
            ^^^ Remove unreferenced `let(:expected_count)` -- its name is never used, so the block never runs.

            it { expect(send("expected_#{type}_value")).to eq(1) }
          end

          context "without" do
            let(:expected_vision_value) { 1 }
            ^^^ Remove unreferenced `let(:expected_vision_value)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end
        end
      RUBY
    end

    it "does not flag a let in the lineage of a reflective call whose name it cannot bound" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          it { expect(send(type.to_sym)).to be_present }
        end
      RUBY
    end

    it "follows the helper methods an included support group calls" do
      support_file("a_thing.rb", 'RSpec.shared_examples("a thing") { it { expect_channel } }')
      support_file("helpers.rb", <<~RUBY)
        module ChannelHelpers
          def expect_channel
            expect(channel).to be_present
          end
        end
      RUBY
      support_file("notifier.rb", <<~RUBY)
        class Notifier
          def expect_channel
            origin
          end
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:channel) { :email }
          let(:origin) { :web }
          ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

          it_behaves_like "a thing"
        end
      RUBY
    end

    it "follows helpers defined in the spec helper files beside spec/support" do
      support_file("helpers.rb", "module Helpers; end")
      File.write(File.join(support_dir, "spec/admin_helper.rb"), <<~RUBY)
        def arbre(&block)
          Arbre::Context.new(defined?(assigns) ? assigns : {}, &block)
        end
      RUBY

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:assigns) { { thing: build(:thing) } }

          it { expect(arbre { panel }).to be_present }
        end
      RUBY
    end

    it "flags a let only where no support helper called in its lineage could read it" do
      support_file("helpers.rb", <<~RUBY)
        def sort_by_parameter
          { name: :sort_by, in: :query }
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "when sorted" do
            let(:sort_by) { "name:asc" }

            parameter sort_by_parameter
          end

          context "when unsorted" do
            let(:per) { 10 }
            ^^^ Remove unreferenced `let(:per)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end
        end
      RUBY
    end

    it "keeps a let only where the metadata a support harness is registered for is in its lineage" do
      support_file("harness.rb", <<~RUBY)
        RSpec.shared_context "things harness" do
          it { expect(query).to be_present }
        end

        RSpec.configure do |config|
          config.include_context "things harness", :things
          config.before(:each, flavor: :sweet) { expect(flavor_text).to be_present }
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "through the harness", :things do
            let(:query) { 1 }
            let(:variables) { {} }
            ^^^ Remove unreferenced `let(:variables)` -- its name is never used, so the block never runs.
          end

          context "directly" do
            let(:query) { 2 }
            ^^^ Remove unreferenced `let(:query)` -- its name is never used, so the block never runs.
          end

          context "sweet", flavor: :sweet do
            let(:flavor_text) { "sugar" }
          end

          context "sour", flavor: :sour do
            let(:flavor_text) { "lemon" }
            ^^^ Remove unreferenced `let(:flavor_text)` -- its name is never used, so the block never runs.
          end
        end
      RUBY
    end

    context "with metadata RSpec derives from a spec's location" do
      before do
        support_file("harness.rb", <<~RUBY)
          RSpec.shared_context("request harness") { it { expect(path).to be_present } }
          RSpec.shared_context("rake harness") { it { expect(task_name).to be_present } }
          RSpec.shared_context("unknown harness") { it { expect(other).to be_present } }

          RSpec.configure do |config|
            config.define_derived_metadata(file_path: %r{/spec/tasks/}) { |metadata| metadata[:type] = :rake }
            config.define_derived_metadata(file_path: Regexp.new("/spec/jobs/")) { |metadata| metadata[:type] = :job }
            config.define_derived_metadata(file_path: SOME_PATHS) { |metadata| metadata[:unknown] = true }
            config.define_derived_metadata(:things) { |metadata| metadata[:derived] = true }
            config.define_derived_metadata { |metadata| metadata[:always] = true }
            config.include_context "request harness", type: :request
            config.include_context "rake harness", type: :rake
            config.include_context "unknown harness", :unknown
          end
        RUBY
      end

      it "keeps a let the harness for the inferred type reads" do
        expect_offense(<<~RUBY, "/app/spec/requests/things_spec.rb")
          RSpec.describe Thing do
            let(:path) { "/things" }
            let(:task_name) { "things:sync" }
            ^^^ Remove unreferenced `let(:task_name)` -- its name is never used, so the block never runs.
            let(:other) { 1 }
          end
        RUBY
      end

      it "keeps a let the harness for a type derived from the path reads" do
        expect_offense(<<~RUBY, "/app/spec/tasks/things_spec.rb")
          RSpec.describe Thing do
            let(:path) { "/things" }
            ^^^ Remove unreferenced `let(:path)` -- its name is never used, so the block never runs.
            let(:task_name) { "things:sync" }
            let(:other) { 1 }
          end
        RUBY
      end
    end

    it "keeps every let where a harness registered for its metadata cannot be resolved" do
      support_file("harness.rb", <<~RUBY)
        RSpec.configure { |config| config.include_context "not defined anywhere", :never }
      RUBY

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing, :never do
          let(:origin) { :web }
        end
      RUBY
    end

    it "keeps a let a module's inclusion hook reads, but not one only its methods read" do
      support_file("helpers.rb", <<~RUBY)
        module ThingHooks
          extend ActiveSupport::Concern

          included do
            before { expect(hooked).to be_present }
          end

          def read_unhooked
            unhooked
          end
        end

        RSpec.configure do |config|
          config.include ThingHooks
          config.include Devise::Test::IntegrationHelpers, type: :request
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:hooked) { 1 }
          let(:unhooked) { 2 }
          ^^^ Remove unreferenced `let(:unhooked)` -- its name is never used, so the block never runs.
        end
      RUBY
    end

    it "does not count hash keys or factory, stub and lookup arguments as references" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:status) { "active" }
          ^^^ Remove unreferenced `let(:status)` -- its name is never used, so the block never runs.
          let(:approved) { true }
          ^^^ Remove unreferenced `let(:approved)` -- its name is never used, so the block never runs.
          let(:sent_at) { Time.current }
          ^^^ Remove unreferenced `let(:sent_at)` -- its name is never used, so the block never runs.
          let(:mode) { :fast }

          before { allow(thing).to receive(:sent_at) }

          it { expect(create(:thing, :approved, status: "x", "mode" => 1)).to be_present }
          it { expect(attributes[:status] || attributes["sent_at"]).to be_nil }
          it { expect(send(:mode)).to eq(:fast) }
        end
      RUBY
    end

    it "keeps a let a call on the example itself reads" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:payroll) { build(:payroll) }
          let(:input) { 1 }
          let(:company) { build(:company) }
          ^^^ Remove unreferenced `let(:company)` -- its name is never used, so the block never runs.

          it { expect(self.payroll).to be_present }
          it { [->(example) { example.input }].each { |check| instance_exec(self, &check) } }
          it { expect(record.company).to be_present }
        end
      RUBY
    end

    it "judges a let in a shared group nested in an example group across the whole file" do
      expect_offense(<<~RUBY)
        RSpec.shared_examples "a top-level thing" do
          let(:top_level) { 1 }
        end

        RSpec.describe Thing do
          shared_examples "a nested thing" do
            let(:read_by_includer) { 1 }
            let(:unused_nested) { 2 }
            ^^^ Remove unreferenced `let(:unused_nested)` -- its name is never used, so the block never runs.
          end

          context "when included" do
            it_behaves_like "a nested thing"

            it { expect(read_by_includer).to eq(1) }
          end
        end
      RUBY
    end

    it "bounds reflective calls by the names their targets could hold" do
      expect_offense(<<~'RUBY')
        RSpec.describe Thing do
          context "literal variable" do
            let(:fixed) { 1 }
            let(:stray) { 2 }
            ^^^ Remove unreferenced `let(:stray)` -- its name is never used, so the block never runs.

            it { target = :fixed; expect(send(target)).to eq(1) }
          end

          context "hash iteration" do
            let(:body_include) { "x" }
            let(:body_other) { "y" }
            ^^^ Remove unreferenced `let(:body_other)` -- its name is never used, so the block never runs.

            it { { include: 1, exclude: 2 }.each { |suffix, _| try("body_#{suffix}") } }
          end

          context "unknown iteration" do
            let(:a_value) { 1 }

            it { names.each { |name| try("#{name}_value") } }
          end

          context "computed" do
            let(:anything) { 1 }

            it { name = "x#{y}"; send(name) }
          end

          context "destructured" do
            let(:another) { 1 }

            it { first, second = pair; send(first) }
          end

          context "interpolated locals" do
            let(:prefixed_value) { 1 }
            let(:built_value) { 2 }
            let(:mixed_value) { 3 }
            let(:called_value) { 4 }

            it { prefix = "prefixed"; try("#{prefix}_value") }
            it { [built, :mixed].each { |part| try("#{part}_value") } }
            it { each_name { |name| try("#{name}_value") } }
          end
        end
      RUBY
    end

    it "keeps a let a reflective call could reach through the hash keys it iterates" do
      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "by role" do
            let(:contractor) { build(:contractor) }
            let(:defaults) { { contractor: false } }

            it { defaults.each { |role, _| expect(self.public_send(role)).to be_present } }
          end

          context "elsewhere" do
            let(:employee) { build(:employee) }
            ^^^ Remove unreferenced `let(:employee)` -- its name is never used, so the block never runs.

            it { expect(build(:thing, employee: 1)).to be_present }
          end
        end
      RUBY
    end

    it "keeps a let a support helper that dispatches over its arguments could be handed" do
      support_file("helpers.rb", <<~RUBY)
        def expect_attributes(record, attributes)
          attributes.each_key { |key| expect(record.public_send(key)).to eq(send(key)) }
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          context "checked" do
            let(:status) { "active" }

            it { expect_attributes(thing, status: 1, "mode" => 2) }
          end

          context "unchecked" do
            let(:mode) { :fast }
            ^^^ Remove unreferenced `let(:mode)` -- its name is never used, so the block never runs.

            it { expect(1).to eq(1) }
          end
        end
      RUBY
    end

    it "keeps every let in the lineage of a reflective call it cannot bound" do
      expect_no_offenses(<<~'RUBY')
        RSpec.describe Thing do
          let(:a) { 1 }
          let(:b) { 2 }

          it { send("#{name}") }
          it { try("#{x; y}_z") }
          it { try("#{}_z") }
        end
      RUBY
    end

    it "reads registrations and metadata in the shapes support files write them" do
      support_file("odd.rb", <<~'RUBY')
        :lonely
        RSpec.shared_context("tagged harness", :tagged) { it { expect(tagged_input).to be_present } }

        module EmptyHelpers; end

        RSpec.configure do |config|
          config.include_context "typed harness", type: some_type
          config.include helper_module
          config.include FactoryBot::Syntax::Methods
          config.include EmptyHelpers
          config.filter_run_when_matching :focus
          config.define_derived_metadata(file_path: %r{/spec/#{dir}/}) { |metadata| metadata[:interpolated] = compute(metadata[:other]) }
          config.define_derived_metadata(file_path: path_for(:thing)) { |metadata| metadata.fetch(:x) }
          config.define_derived_metadata(file_path: Regexp.new(PATH)) { |metadata| metadata[:constant_path] = true }
          config.before(:each, flag: true) { expect({ "string_key" => flag_value }).to be_present }
          config.before(:each, flag: false) { expect(other_flag_value).to be_present }
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing, "description", flag: true do
          let(:string_key) { 1 }
          ^^^ Remove unreferenced `let(:string_key)` -- its name is never used, so the block never runs.
          let(:flag_value) { 2 }
          let(:other_flag_value) { 3 }
          ^^^ Remove unreferenced `let(:other_flag_value)` -- its name is never used, so the block never runs.

          context "tagged", :tagged do
            let(:tagged_input) { 4 }
          end
        end
      RUBY
    end

    it "keeps every let where a harness registered for metadata it cannot read applies" do
      support_file("odd.rb", <<~RUBY)
        RSpec.configure do |config|
          config.include_context "missing harness", flag: some_value
          config.include_context "missing harness", some_metadata
        end
      RUBY

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing, flag: other_value do
          let(:origin) { :web }
        end
      RUBY
    end

    context "with LocalContextIncludes" do
      let(:cop_config) { { "PerExampleGroup" => true, "LocalContextIncludes" => ["include_local_context"] } }
      let(:spec_path) { File.join(support_dir, "spec/things/thing_spec.rb") }

      before do
        other_cops["RSpec"]["Language"]["Includes"]["Context"] << "include_local_context"
        FileUtils.mkdir_p(File.dirname(spec_path))
      end

      it "resolves the sibling context file it loads, once" do
        File.write(File.join(File.dirname(spec_path), "context.rb"), "local_context { before { expect(origin).to be_present } }")
        File.write(File.join(File.dirname(spec_path), "payroll_context.rb"), "local_context { before { expect(channel).to be_present } }")

        expect_offense(<<~RUBY, spec_path)
          RSpec.describe Thing do
            context "default" do
              include_local_context

              let(:origin) { :web }
              let(:channel) { :email }
              ^^^ Remove unreferenced `let(:channel)` -- its name is never used, so the block never runs.
            end

            context "named" do
              include_local_context :payroll
              include_local_context :payroll

              let(:channel) { :sms }
            end
          end
        RUBY
      end

      it "keeps every let in the lineage of a local context it cannot find, parse or name" do
        File.write(File.join(File.dirname(spec_path), "broken_context.rb"), "local_context do")

        expect_no_offenses(<<~RUBY, spec_path)
          RSpec.describe Thing do
            context "missing" do
              include_local_context :absent

              let(:origin) { :web }
            end

            context "computed" do
              include_local_context name

              let(:channel) { :sms }
            end

            context "broken" do
              include_local_context :broken

              let(:status) { :sms }
            end
          end
        RUBY
      end
    end

    it "resolves each support group once" do
      support_file("a_thing.rb", 'RSpec.shared_examples("a thing") { it { expect(1).to eq(1) } }')

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }
          ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

          it_behaves_like "a thing"
          it_behaves_like "a thing"
        end
      RUBY
      expect(described_class.instance_variable_get(:@support_reads).keys).to contain_exactly([:groups, "a thing"])
    end

    it "reads names from symbols, bare calls and string tokens across a support file" do
      support_file("a_thing.rb", <<~RUBY)
        RSpec.shared_context "a thing" do
          let(:defaulted) { 1 }
          it { expect(subject&.value).to eq(["channel and more", "\\xc2"]) }
          it { send }
        end
      RUBY

      expect_offense(<<~RUBY)
        RSpec.describe Thing do
          let(:defaulted) { 2 }
          let(:channel) { :email }
          let(:origin) { :web }
          ^^^ Remove unreferenced `let(:origin)` -- its name is never used, so the block never runs.

          include_context "a thing"
        end
      RUBY
    end

    it "treats a support file that cannot be parsed as defining nothing" do
      support_file("broken.rb", 'RSpec.shared_examples("a thing") do')

      expect_no_offenses(<<~RUBY)
        RSpec.describe Thing do
          let(:origin) { :web }

          it_behaves_like "a thing"
        end
      RUBY
    end
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
    it "enumerates spec/support .rb paths via Dir.glob without touching git" do
      allow(Dir).to receive(:glob).with(RuboCop::Cop::Gusto::UnreferencedLet::SUPPORT_FILES_GLOB).and_return(["spec/support/from_glob.rb"])

      expect(described_class.support_file_paths).to eq(["spec/support/from_glob.rb"])
    end
  end
end
