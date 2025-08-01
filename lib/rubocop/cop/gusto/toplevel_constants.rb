# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks that no top-level constants (excluding classes and modules)
      # are defined. This rule exists to prevent accidental pollution of the
      # global namespace as well as cases where application code has
      # accidentally depended on test code.
      #
      # By default, this check is limited to files in `app/`, `lib/`, and
      # `spec/` directories, except in the root of `lib/` and in support files
      # in `spec/support/`.
      #
      # @example when in a checked directory
      #   # bad
      #   FOO = 'bar' # lib/foo/bar.rb
      #
      #   # bad
      #   FOO = 'bar' # app/models/foo.rb
      #
      #   # bad
      #   FOO = 'bar' # spec/foo.rb
      #
      #   # good
      #   FOO = 'bar' # spec/spec_helper.rb
      #
      #   # good
      #   class MyClass # lib/foo/bar.rb
      #     FOO = 'bar'
      #   end
      #
      # @example when in a `spec/support/` file
      #   # good
      #   FOO = 'bar' # spec/support/foo/bar.rb
      #
      # @example when in a `config/` file
      #   # good
      #   FOO = 'bar' # config/initializers/foo.rb
      #
      class ToplevelConstants < Base
        MSG = "Top-level constants should be defined in an initializer. See https://github.com/Gusto/rubocop-gusto/blob/main/lib/rubocop/cop/gusto/toplevel_constants.rb"

        def on_casgn(node)
          # Allow nested constants
          return unless node.parent.nil? || node.ancestors.all?(&:begin_type?)
          # Allow one-liners like `MyClass::MY_CONSTANT = 10`
          return unless node.children.first.nil?

          add_offense(node)
        end
      end
    end
  end
end
