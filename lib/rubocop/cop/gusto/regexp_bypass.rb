# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Ensures that regular expressions use `\A` and `\z` anchors instead
      # of `^` and `$` when matching the start or end of a string. This is
      # critical for security validations as `^` and `$` will match the start/end
      # of any line in a string, not just the start/end of the entire string.
      #
      # @example
      #   # bad - validating only a single line of input which could be split across multiple lines
      #   /^foo/
      #   /foo$/
      #   /^foo$/
      #
      #   # good
      #   /\Afoo/
      #   /foo\z/
      #   /\Afoo\z/
      #
      #   # good - multiline mode is allowed
      #   /^foo/m
      #   /foo$/m
      #
      #   # okay - anchors in the middle of the pattern are not flagged
      #   /foo^bar/
      #   /foo$bar/
      #
      # @safety
      #   We choose to consider this cop safe even though the code is not equivalent.
      #   Replacing `^` and `$` with `\A` and `\z` will make the regex more strict,
      #   which is the intended behavior for securely validating input.
      #
      # @see https://ruby-doc.org/core/Regexp.html
      # @see https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS
      #
      class RegexpBypass < Base
        extend AutoCorrector

        MSG = 'Regular expressions matching a single line should use \A instead of ^ and \z instead of $'
        PROHIBITED_ANCHOR = "^"
        PROHIBITED_END_ANCHOR = "$"

        def on_regexp(node)
          return if node.children.find(&:regopt_type?)&.source&.include?("m")

          first_child = node.children.first
          return unless first_child && !first_child.regopt_type?

          captureless_source = first_child.source.delete("()") # Remove parentheses to check actual content
          return unless captureless_source.start_with?(PROHIBITED_ANCHOR) || captureless_source.end_with?(PROHIBITED_END_ANCHOR)

          add_offense(first_child) do |corrector|
            source_buffer = first_child.source_range.source_buffer
            actual_source = first_child.source

            if captureless_source.start_with?(PROHIBITED_ANCHOR)
              # Find the position of ^ within the source, accounting for parentheses
              caret_pos = actual_source.index(PROHIBITED_ANCHOR)
              start_pos = first_child.source_range.begin_pos + caret_pos
              corrector.replace(
                Parser::Source::Range.new(
                  source_buffer,
                  start_pos,
                  start_pos + 1
                ),
                '\A'
              )
            end

            if captureless_source.end_with?(PROHIBITED_END_ANCHOR)
              # Find the position of $ within the source, accounting for parentheses
              dollar_pos = actual_source.rindex(PROHIBITED_END_ANCHOR)
              end_pos = first_child.source_range.begin_pos + dollar_pos + 1
              corrector.replace(
                Parser::Source::Range.new(
                  source_buffer,
                  end_pos - 1,
                  end_pos
                ),
                '\z'
              )
            end
          end
        end
      end
    end
  end
end
