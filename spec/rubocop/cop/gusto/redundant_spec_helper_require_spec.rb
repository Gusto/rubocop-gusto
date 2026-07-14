# typed: false
# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe RuboCop::Cop::Gusto::RedundantSpecHelperRequire, :config do
  let(:root) { Dir.mktmpdir }

  after { ::FileUtils.remove_entry(root) if ::File.directory?(root) }

  # Write a real fixture file under the temp project root (the cop reads .rspec / *.gemspec /
  # spec/rails_helper.rb from disk to decide redundancy).
  def write(relative_path, contents = "")
    path = ::File.join(root, relative_path)
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.write(path, contents)
    path
  end

  def spec_path
    ::File.join(root, "spec", "foo_spec.rb")
  end

  context "when the governing .rspec `--require`s spec_helper" do
    before { write(".rspec", "--require spec_helper\n") }

    it "removes a redundant `require 'spec_helper'` and the trailing blank" do
      expect_offense(<<~RUBY, spec_path)
        require "spec_helper"
        ^^^^^^^^^^^^^^^^^^^^^ Redundant `require 'spec_helper'` - the governing .rspec already `--require`s it.

        RSpec.describe Foo do
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Foo do
        end
      RUBY
    end

    it "removes a redundant `require_relative` to spec_helper" do
      expect_offense(<<~RUBY, spec_path)
        require_relative "../spec_helper"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Redundant `require 'spec_helper'` - the governing .rspec already `--require`s it.
        RSpec.describe Foo do
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Foo do
        end
      RUBY
    end

    it "removes only the require line when it is not followed by a blank line" do
      expect_offense(<<~RUBY, spec_path)
        require "spec_helper"
        ^^^^^^^^^^^^^^^^^^^^^ Redundant `require 'spec_helper'` - the governing .rspec already `--require`s it.
        RSpec.describe Foo do
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Foo do
        end
      RUBY
    end

    it "removes `require 'rails_helper'` when rails_helper.rb is a pure spec_helper shim" do
      write("spec/rails_helper.rb", "# frozen_string_literal: true\n\nrequire 'spec_helper'\n")

      expect_offense(<<~RUBY, spec_path)
        require "rails_helper"
        ^^^^^^^^^^^^^^^^^^^^^^ Redundant `require 'rails_helper'` - the governing .rspec already `--require`s it.
        RSpec.describe Foo do
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Foo do
        end
      RUBY
    end

    it "keeps `require 'rails_helper'` when rails_helper.rb does real setup (not a shim)" do
      write("spec/rails_helper.rb", "require 'spec_helper'\nrequire 'rails'\nSomeApp.boot\n")

      expect_no_offenses(<<~RUBY, spec_path)
        require "rails_helper"
        RSpec.describe Foo do
        end
      RUBY
    end

    it "keeps `require 'rails_helper'` when there is no rails_helper.rb to shim" do
      expect_no_offenses(<<~RUBY, spec_path)
        require "rails_helper"
        RSpec.describe Foo do
        end
      RUBY
    end

    it "ignores requires of other files" do
      expect_no_offenses(<<~RUBY, spec_path)
        require "json"
        RSpec.describe Foo do
        end
      RUBY
    end

    it "ignores a non-string require argument" do
      expect_no_offenses(<<~RUBY, spec_path)
        require SomeConstant
        RSpec.describe Foo do
        end
      RUBY
    end

    it "does not edit the spec_helper.rb / rails_helper.rb files themselves" do
      expect_no_offenses(<<~RUBY, ::File.join(root, "spec", "rails_helper.rb"))
        require "spec_helper"
      RUBY
    end
  end

  context "when the governing .rspec `--require`s rails_helper (short `-r` form) but not spec_helper" do
    before { write(".rspec", "-r rails_helper\n--require some_other_support\n") }

    it "removes a redundant `require 'spec_helper'` (loaded transitively via rails_helper)" do
      expect_offense(<<~RUBY, spec_path)
        require "spec_helper"
        ^^^^^^^^^^^^^^^^^^^^^ Redundant `require 'spec_helper'` - the governing .rspec already `--require`s it.
        RSpec.describe Foo do
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Foo do
        end
      RUBY
    end
  end

  context "when the governing .rspec does not auto-require the helper" do
    before { write(".rspec", "--color\n") }

    it "keeps the inline require" do
      expect_no_offenses(<<~RUBY, spec_path)
        require "spec_helper"
        RSpec.describe Foo do
        end
      RUBY
    end
  end

  context "when the file's project has no .rspec of its own" do
    it "keeps the require for a standalone gem (gemspec boundary)" do
      write("thing.gemspec", "Gem::Specification.new\n")

      expect_no_offenses(<<~RUBY, spec_path)
        require "spec_helper"
        RSpec.describe Foo do
        end
      RUBY
    end

    it "keeps the require for a standalone project (Gemfile boundary)" do
      write("Gemfile", "source 'https://rubygems.org'\n")

      expect_no_offenses(<<~RUBY, spec_path)
        require "spec_helper"
        RSpec.describe Foo do
        end
      RUBY
    end

    it "keeps the require when no governing .rspec exists anywhere above the file" do
      expect_no_offenses(<<~RUBY, spec_path)
        require "spec_helper"
        RSpec.describe Foo do
        end
      RUBY
    end
  end
end
