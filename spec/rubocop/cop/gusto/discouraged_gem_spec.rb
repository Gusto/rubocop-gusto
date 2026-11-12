# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe RuboCop::Cop::Gusto::DiscouragedGem, :config do
  let(:cop_config) do
    {
      "Gems" => {},
    }
  end

  context "when using an allowed gem" do
    let(:source) do
      <<~RUBY
        gem 'rspec'
        gem 'rubocop'
        gem 'rails'
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when using add_dependency with an allowed gem" do
    let(:source) do
      <<~RUBY
        spec.add_dependency 'rspec'
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when using add_development_dependency with an allowed gem" do
    let(:source) do
      <<~RUBY
        spec.add_development_dependency 'rubocop'
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when gem method is called with a variable" do
    let(:source) do
      <<~RUBY
        gem gem_name
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when gem method is called with an expression" do
    let(:source) do
      <<~RUBY
        gem some_method_call
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when gem method is called without arguments" do
    let(:source) do
      <<~RUBY
        gem
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when add_dependency is called without arguments" do
    let(:source) do
      <<~RUBY
        spec.add_dependency
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when add_dependency is called with a variable" do
    let(:source) do
      <<~RUBY
        spec.add_dependency gem_name
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when add_development_dependency is called with a variable" do
    let(:source) do
      <<~RUBY
        spec.add_development_dependency gem_name
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when using a discouraged gem with custom message" do
    let(:cop_config) do
      {
        "Gems" => {
          "some_gem" => "Use the approved alternative instead.",
        },
      }
    end

    let(:source) do
      <<~RUBY
        gem 'some_gem'
        ^^^^^^^^^^^^^^ Avoid using the 'some_gem' gem. Use the approved alternative instead.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using a discouraged gem with empty message" do
    let(:cop_config) do
      {
        "Gems" => {
          "some_other_gem" => "",
        },
      }
    end

    let(:source) do
      <<~RUBY
        gem 'some_other_gem'
        ^^^^^^^^^^^^^^^^^^^^ Avoid using the 'some_other_gem' gem.#{' '}
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when Gems config is not set" do
    let(:cop_config) do
      {}
    end

    it "does not register an offense for any gem" do
      source = <<~RUBY
        gem 'anything'
      RUBY

      expect_no_offenses(source)
    end
  end

  context "when method is not in RESTRICT_ON_SEND" do
    let(:cop_config) do
      {
        "Gems" => {
          "some_gem" => "Don't use this!",
        },
      }
    end

    it "does not register an offense even if gem name matches" do
      source = <<~RUBY
        require 'some_gem'
        install 'some_gem'
        load 'some_gem'
      RUBY

      expect_no_offenses(source)
    end
  end

  context "with a lockfile" do
    let(:root) { Dir.mktmpdir }
    let(:cop_config) { { "Gems" => { "ostruct" => "Use Struct instead." } } }
    let(:gemfile) { File.join(root, "Gemfile") }

    after { FileUtils.remove_entry(root) }

    def write_lockfile(specs, dependencies, name: "Gemfile.lock", path_specs: nil)
      path_section = path_specs ? "PATH\n  remote: .\n  specs:\n#{path_specs}\n" : ""
      File.write(File.join(root, name), <<~LOCK)
        #{path_section}GEM
          remote: https://rubygems.org/
          specs:
        #{specs.gsub(/^/, '    ')}
        PLATFORMS
          ruby

        DEPENDENCIES
        #{dependencies.map { |dep| "  #{dep}" }.join("\n")}

        BUNDLED WITH
           2.6.0
      LOCK
    end

    it "flags a transitive discouraged gem on the Gemfile line that pulls it in" do
      write_lockfile(<<~SPECS, %w(rails slack-ruby-client))
        gli (2.22.2)
          ostruct
        ostruct (0.6.1)
        rails (8.0.0)
        slack-ruby-client (3.2.0)
          gli
      SPECS

      expect_offense(<<~RUBY, gemfile)
        gem 'rails'
        gem 'slack-ruby-client'
        ^^^^^^^^^^^^^^^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via slack-ruby-client -> gli -> ostruct. Use Struct instead.
      RUBY
    end

    it "flags each Gemfile dependency that pulls in a discouraged gem" do
      write_lockfile(<<~SPECS, %w(icalendar oj))
        icalendar (2.12.5)
          ostruct
        oj (3.17.7)
          ostruct (>= 0.2)
        ostruct (0.6.1)
      SPECS

      expect_offense(<<~RUBY, gemfile)
        gem 'icalendar'
        ^^^^^^^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via icalendar -> ostruct. Use Struct instead.
        gem 'oj', '~> 3.17'
        ^^^^^^^^^^^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via oj -> ostruct. Use Struct instead.
      RUBY
    end

    it "reports the shortest path when several lead to the discouraged gem" do
      write_lockfile(<<~SPECS, %w(app))
        app (1.0.0)
          deep
          shallow
        deep (1.0.0)
          deeper
        deeper (1.0.0)
          ostruct
        ostruct (0.6.1)
        shallow (1.0.0)
          ostruct
      SPECS

      expect_offense(<<~RUBY, gemfile)
        gem 'app'
        ^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via app -> shallow -> ostruct. Use Struct instead.
      RUBY
    end

    it "handles dependency cycles and platform-specific duplicate specs" do
      write_lockfile(<<~SPECS, %w(nokogiri))
        mini_portile2 (2.8.0)
          nokogiri
        nokogiri (1.16.0)
          mini_portile2
          ostruct
        nokogiri (1.16.0-arm64-darwin)
          ostruct
        ostruct (0.6.1)
      SPECS

      expect_offense(<<~RUBY, gemfile)
        gem 'nokogiri'
        ^^^^^^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via nokogiri -> ostruct. Use Struct instead.
      RUBY
    end

    it "flags a direct discouraged gem only once" do
      write_lockfile("ostruct (0.6.1)\n", %w(ostruct))

      expect_offense(<<~RUBY, gemfile)
        gem 'ostruct'
        ^^^^^^^^^^^^^ Avoid using the 'ostruct' gem. Use Struct instead.
      RUBY
    end

    it "flags dependencies of the project's own gemspec on the gemspec line" do
      write_lockfile("gli (2.22.2)\n  ostruct\nostruct (0.6.1)\n", %w(my_gem!), path_specs: "    my_gem (1.0.0)\n      gli")

      expect_offense(<<~RUBY, gemfile)
        source 'https://rubygems.org'
        gemspec
        ^^^^^^^ Avoid using the 'ostruct' gem, pulled in via my_gem -> gli -> ostruct. Use Struct instead.
      RUBY
    end

    it "flags the first line when the pulling dependency is not declared in the Gemfile" do
      write_lockfile("gli (2.22.2)\n  ostruct\nostruct (0.6.1)\n", %w(gli ostruct))

      expect_offense(<<~RUBY, gemfile)
        eval_gemfile 'Gemfile.shared'
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via gli -> ostruct. Use Struct instead. Avoid using the 'ostruct' gem. Use Struct instead.
      RUBY
    end

    it "flags a lockfile it cannot parse" do
      File.write(File.join(root, "Gemfile.lock"), "<<<<<<< HEAD\nGEM\n=======\n>>>>>>> main\n")

      expect_offense(<<~RUBY, gemfile)
        gem 'rails'
        ^^^^^^^^^^^ Could not parse Gemfile.lock to check for discouraged gems.
      RUBY
    end

    it "reads gems.locked for gems.rb" do
      write_lockfile("gli (2.22.2)\n  ostruct\nostruct (0.6.1)\n", %w(gli), name: "gems.locked")

      expect_offense(<<~RUBY, File.join(root, "gems.rb"))
        gem 'gli'
        ^^^^^^^^^ Avoid using the 'ostruct' gem, pulled in via gli -> ostruct. Use Struct instead.
      RUBY
    end

    it "only checks direct dependencies when there is no lockfile" do
      expect_no_offenses("gem 'slack-ruby-client'\n", gemfile)
    end

    it "does not check the lockfile from a gemspec" do
      write_lockfile("gli (2.22.2)\n  ostruct\nostruct (0.6.1)\n", %w(gli))

      expect_no_offenses("spec.add_dependency 'gli'\n", File.join(root, "my_gem.gemspec"))
    end

    it "does not check the lockfile for an empty Gemfile" do
      write_lockfile("gli (2.22.2)\n  ostruct\nostruct (0.6.1)\n", %w(gli))

      expect_no_offenses("", gemfile)
    end

    context "when no gems are discouraged" do
      let(:cop_config) { { "Gems" => {} } }

      it "does not read the lockfile" do
        write_lockfile("gli (2.22.2)\n  ostruct\nostruct (0.6.1)\n", %w(gli))

        expect_no_offenses("gem 'gli'\n", gemfile)
      end
    end

    describe "#external_dependency_checksum" do
      it "changes when the project lockfile changes" do
        Dir.chdir(root) do
          expect(cop.external_dependency_checksum).to be_nil

          write_lockfile("ostruct (0.6.1)\n", %w(ostruct))
          first = described_class.new(config).external_dependency_checksum
          write_lockfile("ostruct (0.6.2)\n", %w(ostruct))

          expect(described_class.new(config).external_dependency_checksum).not_to eq(first)
        end
      end
    end
  end
end
