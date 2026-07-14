# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags an inline `require 'spec_helper'` / `require 'rails_helper'` (or the
      # `require_relative` equivalent) that the governing `.rspec` already loads via
      # `--require`, making the inline require a redundant no-op.
      #
      # Correctness is per file: the cop resolves the `.rspec` that governs the file by walking
      # up to the nearest ancestor `.rspec`, but stops at a project boundary (a directory holding
      # a `*.gemspec` or `Gemfile`). A project with no `.rspec` of its own is therefore never
      # attributed a parent project's `.rspec` -- e.g. a standalone gem/engine that boots its own
      # test environment keeps its inline require. Packs (no gemspec/Gemfile) still resolve to the
      # repo-root `.rspec`.
      #
      # `spec_helper.rb` / `rails_helper.rb` themselves are never edited (they are the definitions
      # and the `rails_helper` -> `spec_helper` shim).
      #
      # `rails_helper` is treated as redundant only when the governing `.rspec` auto-requires it
      # directly, or auto-requires `spec_helper` AND the project's `spec/rails_helper.rb` is a pure
      # shim (nothing but `require 'spec_helper'`). Otherwise it is kept, since a `rails_helper`
      # that does real setup (e.g. boots Rails) is not covered by `spec_helper`.
      #
      # @example
      #   # bad (the governing .rspec already `--require`s it)
      #   require 'spec_helper'
      #   RSpec.describe Foo do
      #   end
      #
      #   # good
      #   RSpec.describe Foo do
      #   end
      class RedundantSpecHelperRequire < Base
        extend AutoCorrector
        include RangeHelp

        MSG = "Redundant `require '%{name}'` - the governing .rspec already `--require`s it."
        HELPERS = %w(spec_helper rails_helper).freeze
        RESTRICT_ON_SEND = %i(require require_relative).freeze

        # @!method require_path(node)
        def_node_matcher :require_path, <<~PATTERN
          (send nil? {:require :require_relative} (str $_))
        PATTERN

        def on_send(node)
          return unless (path = require_path(node))

          name = helper_name(path)
          return unless name
          return if helper_definition_file?
          return unless redundant?(name)

          add_offense(node, message: format(MSG, name:)) do |corrector|
            corrector.remove(removal_range(node))
          end
        end
        alias_method :on_csend, :on_send

        private

        # 'spec_helper' | 'rails_helper' | nil, from 'spec_helper', 'rails_helper',
        # 'rails_helper.rb', or a require_relative path such as '../spec_helper'.
        def helper_name(path)
          base = ::File.basename(path.to_s, ".rb")
          base if HELPERS.include?(base)
        end

        # Never edit the helper/shim files themselves.
        def helper_definition_file?
          HELPERS.include?(::File.basename(processed_source.file_path.to_s, ".rb"))
        end

        def redundant?(name)
          rspec = governing_rspec
          return false unless rspec

          required = auto_required_helpers(rspec)
          return true if required.include?(name)

          if name == "rails_helper"
            required.include?("spec_helper") && rails_helper_shim?(::File.dirname(rspec))
          else
            # rails_helper.rb conventionally requires spec_helper, so a .rspec that auto-requires
            # rails_helper loads spec_helper too.
            required.include?("rails_helper")
          end
        end

        # The `.rspec` that governs this file: nearest ancestor `.rspec`, not crossing a project
        # boundary (a dir with a `*.gemspec` or `Gemfile`). Returns nil when the file's project
        # has no `.rspec` of its own.
        def governing_rspec
          dir = ::File.dirname(::File.expand_path(processed_source.file_path.to_s))
          loop do
            rspec = ::File.join(dir, ".rspec")
            return rspec if ::File.file?(rspec)
            return nil if project_boundary?(dir)

            parent = ::File.dirname(dir)
            return nil if parent == dir

            dir = parent
          end
        end

        def project_boundary?(dir)
          return true if ::File.file?(::File.join(dir, "Gemfile"))

          !::Dir.glob(::File.join(dir, "*.gemspec")).empty?
        end

        # Helper basenames the `.rspec` auto-requires via `--require`/`-r`.
        def auto_required_helpers(rspec_path)
          ::File.read(rspec_path).each_line.with_object([]) do |line, acc|
            line.scan(/(?:--require|-r)[=\s]+(\S+)/) do |(mod)|
              base = ::File.basename(mod, ".rb")
              acc << base if HELPERS.include?(base)
            end
          end
        end

        # True when <root>/spec/rails_helper.rb exists and is a pure shim whose only executable
        # line is `require 'spec_helper'` (magic comments / blank lines / comments ignored).
        def rails_helper_shim?(root_dir)
          path = ::File.join(root_dir, "spec", "rails_helper.rb")
          return false unless ::File.file?(path)

          code = ::File.readlines(path).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
          code.length == 1 && code.first.match?(/\Arequire(?:_relative)?\s+['"][^'"]*spec_helper['"]\z/)
        end

        # Remove the require line, absorbing one immediately-following blank line so the fix does
        # not leave a stray/duplicate blank.
        def removal_range(node)
          buffer = processed_source.buffer
          start_line = node.source_range.first_line
          end_line = node.source_range.last_line
          following = processed_source.lines[end_line] # 0-indexed => the line after end_line
          end_line += 1 if following && following.strip.empty?

          range_by_whole_lines(
            buffer.line_range(start_line).join(buffer.line_range(end_line)),
            include_final_newline: true
          )
        end
      end
    end
  end
end
