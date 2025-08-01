# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "rubocop/gusto/config_yml"

RSpec.describe RuboCop::Gusto::ConfigYml do
  let(:unsorted_path) { File.expand_path("../../fixtures/unsorted_rubocop.yml", __dir__) }
  let(:sorted_path)   { File.expand_path("../../fixtures/sorted_rubocop.yml", __dir__) }

  describe "templates" do
    it "ensure our template is up to date" do
      template_path = File.expand_path("../../../lib/rubocop/gusto/templates/rubocop.yml", __dir__)
      config = described_class.load_file(template_path)
      config.add_plugin(%w(rubocop-gusto rubocop-rspec rubocop-performance rubocop-rake))
      config.add_inherit_gem("rubocop-gusto", "config/default.yml")
      config.sort!
      expect(File.readlines(template_path)).to eq(config.lines), "Template is out of date. Run `bundle exec rake update_template` to update it."
    end
  end

  describe ".load_file" do
    it "reads and writes the file as expected" do
      Tempfile.create(["rubocop_unsorted", ".yml"]) do |tmpfile|
        # Copy unsorted fixture to temp file
        FileUtils.cp(unsorted_path, tmpfile.path)
        # Sort the file in place
        described_class.load_file(tmpfile.path).sort!.write(tmpfile.path)
        # Compare with sorted fixture
        expect(File.read(tmpfile.path)).to eq(File.read(sorted_path))
      end
    end
  end

  describe "#empty?" do
    it "returns false if the file has lines" do
      expect(described_class.load_file(sorted_path).empty?).to be_falsey
    end

    it "returns true if the file does not exist" do
      expect(described_class.load_file("nonexistent_file.yml").empty?).to be_truthy
    end

    it "returns true if the file has no lines" do
      Tempfile.create(["rubocop_empty", ".yml"]) do |tmpfile|
        tmpfile.write("")
        expect(described_class.load_file(tmpfile.path).empty?).to be_truthy
      end
    end
  end

  describe "#lines" do
    it "returns the lines in the file" do
      config = described_class.load_file(sorted_path)
      expect(config.lines).to eq(File.readlines(sorted_path))
    end

    it "returns empty array if the file has no lines" do
      expect(described_class.new([]).lines).to eq([])
    end

    it "it cleans whitespace" do
      config = described_class.new(["\n", "  \n", "\n", "  \n", "# this is an empty file\n", "\n", "\n"])
      expect(config.lines).to eq(["# this is an empty file\n"])
    end
  end

  describe "#add_inherit_gem" do
    it "adds the inherit_gem to the preamble when it doesn not exist" do
      config = described_class.new(<<~YAML.lines)
        plugins:
          - rubocop-gusto
          - rubocop-rspec
      YAML

      config.add_inherit_gem("rubocop-gusto", "config/default.yml")

      expect(config.to_s).to eq(<<~YAML)
        inherit_gem:
          rubocop-gusto:
            - config/default.yml

        plugins:
          - rubocop-gusto
          - rubocop-rspec
      YAML
    end

    it "adds to inherit_gem when the gem doesn't exist" do
      config = described_class.new(<<~YAML.lines)
        inherit_gem:
          rubocop-custom: config/default.yml
      YAML

      config.add_inherit_gem("rubocop-gusto", "config/default.yml")

      expect(config.to_s).to eq(<<~YAML)
        inherit_gem:
          rubocop-custom: config/default.yml
          rubocop-gusto:
            - config/default.yml
      YAML
    end

    it "doesn't add the inherit_gem to the preamble when the gem exists" do
      config = described_class.new(<<~YAML.lines)
        inherit_gem:
          rubocop-gusto: config/default.yml
      YAML

      config.add_inherit_gem("rubocop-gusto", "config/default.yml")

      expect(config.to_s).to eq(<<~YAML)
        inherit_gem:
          rubocop-gusto:
            - config/default.yml
      YAML
    end

    it "doesn't add the inherit_gem to the preamble when the key exists in a different format" do
      config = described_class.new(<<~YAML.lines)
        inherit_gem:
          rubocop-gusto:
            - config/default.yml
      YAML

      config.add_inherit_gem("rubocop-gusto", "config/default.yml")

      expect(config.to_s).to eq(<<~YAML)
        inherit_gem:
          rubocop-gusto:
            - config/default.yml
      YAML
    end

    context "when the project is a Rails app" do
      before do
        allow(File).to receive(:exist?).with("config/application.rb").and_return(true)
      end

      it "adds the inherit_gem to the preamble when it doesn not exist" do
        config = described_class.new(<<~YAML.lines)
          AllCops:
            Enabled: true
        YAML

        config.add_inherit_gem("rubocop-gusto", ["config/default.yml", "config/rails.yml"])

        expect(config.to_s).to eq(<<~YAML)
          inherit_gem:
            rubocop-gusto:
              - config/default.yml
              - config/rails.yml

          AllCops:
            Enabled: true
        YAML
      end

      it "adds the inherit_gem to the preamble when another inherit_gem exists" do
        config = described_class.new(<<~YAML.lines)
          inherit_gem:
            rubocop-custom: config/default.yml
        YAML

        config.add_inherit_gem("rubocop-gusto", ["config/default.yml", "config/rails.yml"])

        expect(config.to_s).to eq(<<~YAML)
          inherit_gem:
            rubocop-custom: config/default.yml
            rubocop-gusto:
              - config/default.yml
              - config/rails.yml
        YAML
      end

      it "adds the inherit_gem to the preamble when rubocop-gusto already exists" do
        config = described_class.new(<<~YAML.lines)
          inherit_gem:
            rubocop-gusto: config/default.yml
        YAML

        config.add_inherit_gem("rubocop-gusto", ["config/default.yml", "config/rails.yml"])

        expect(config.to_s).to eq(<<~YAML)
          inherit_gem:
            rubocop-gusto:
              - config/default.yml
              - config/rails.yml
        YAML
      end

      it "adds the inherit_gem to the preamble when rubocop-gusto already exists in a different format" do
        config = described_class.new(<<~YAML.lines)
          inherit_gem:
            rubocop-gusto:
              - config/default.yml
        YAML

        config.add_inherit_gem("rubocop-gusto", ["config/default.yml", "config/rails.yml"])

        expect(config.to_s).to eq(<<~YAML)
          inherit_gem:
            rubocop-gusto:
              - config/default.yml
              - config/rails.yml
        YAML
      end

      it "doesn't add the inherit_gem to the preamble when rubocop-gusto already exists correctly" do
        config = described_class.new(<<~YAML.lines)
          inherit_gem:
            rubocop-gusto:
              - config/rails.yml
              - config/default.yml
        YAML

        config.add_inherit_gem("rubocop-gusto", ["config/default.yml", "config/rails.yml"])

        expect(config.to_s).to eq(<<~YAML)
          inherit_gem:
            rubocop-gusto:
              - config/default.yml
              - config/rails.yml
        YAML
      end
    end
  end

  describe "#add_plugin" do
    it "creates the plugins section when it doesn't exist" do
      config = described_class.new(<<~YAML.lines)
        AllCops:
          Enabled: true
      YAML

      config.add_plugin(%w(rubocop-gusto))
      config.sort!

      expect(config.to_s).to eq(<<~YAML)
        plugins:
          - rubocop-gusto

        AllCops:
          Enabled: true
      YAML
    end

    it "adds to the section when there are none added yet" do
      config = described_class.new(<<~YAML.lines)
        plugins:
      YAML

      config.add_plugin(%w(rubocop-gusto))
      config.sort!

      expect(config.to_s).to eq(<<~YAML)
        plugins:
          - rubocop-gusto
      YAML
    end

    it "adds the plugin when the plugins section exists but doesn't contain the plugin" do
      config = described_class.new(<<~YAML.lines)
        plugins:
          - rubocop-rspec
      YAML

      config.add_plugin(%w(rubocop-gusto))

      expect(config.to_s).to eq(<<~YAML)
        plugins:
          - rubocop-rspec
          - rubocop-gusto
      YAML
    end

    it "doesn't add the plugin when it already exists in the plugins section" do
      config = described_class.new(<<~YAML.lines)
        plugins:
        - rubocop-gusto
        - rubocop-rspec
      YAML

      config.add_plugin(%w(rubocop-gusto))

      expect(config.to_s).to eq(<<~YAML)
        plugins:
          - rubocop-gusto
          - rubocop-rspec
      YAML
    end
  end

  describe "#sort!" do
    it "sorts the cops in the file as expected" do
      config = described_class.new(File.readlines(unsorted_path))
      expected = File.readlines(sorted_path).map(&:rstrip).join("\n") << "\n"
      expect(config.sort!.to_s).to eq(expected)
    end

    it "sorts a file with no cops" do
      config = described_class.new(<<~YAML.lines)
        plugins:
          - rubocop-rspec
          - rubocop-gusto
      YAML
      expect(config.sort!.to_s).to eq(<<~YAML)
        plugins:
          - rubocop-rspec
          - rubocop-gusto
      YAML
    end

    it "sorts a file with only cops and broken comments that stick to the cop" do
      config = described_class.new(<<~YAML.lines)
        # a top level comment

        # this comment sticks to the cop below me
        RSpec/AnyInstance:
          Enabled: true
        AllCops:
          Enabled: true
      YAML

      expect(config.sort!.to_s).to eq(<<~YAML)
        AllCops:
          Enabled: true

        # a top level comment

        # this comment sticks to the cop below me
        RSpec/AnyInstance:
          Enabled: true
      YAML
    end

    it "sorts a file that ends with a comment without losing the comment" do
      config = described_class.new(<<~YAML.lines)
        AllCops:
          Enabled: true
        # why is this the last line?
      YAML

      expect(config.sort!.to_s).to eq(<<~YAML)
        # why is this the last line?

        AllCops:
          Enabled: true
      YAML
    end

    it "sorts cops that have a comment on the same line" do
      config = described_class.new(<<~YAML.lines)
        Gusto/SomeCop: # this comment was causing the cop name matcher to fail
          Enabled: true

        AllCops:
          Enabled: true
      YAML

      expect(config.sort!.to_s).to eq(<<~YAML)
        AllCops:
          Enabled: true

        Gusto/SomeCop: # this comment was causing the cop name matcher to fail
          Enabled: true
      YAML
    end

    it "it handles the case where there are cops before preamble" do
      config = described_class.new(<<~YAML.lines)
        RSpec/AnyInstance:
          Enabled: true

        plugins:
          - rubocop-rspec
          - rubocop-gusto

        AllCops:
          Enabled: true
      YAML

      expect(config.sort!.to_s).to eq(<<~YAML)
        plugins:
          - rubocop-rspec
          - rubocop-gusto

        AllCops:
          Enabled: true

        RSpec/AnyInstance:
          Enabled: true
      YAML
    end
  end
end
