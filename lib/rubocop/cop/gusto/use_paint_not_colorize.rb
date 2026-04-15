# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Requires the use of the `paint` gem for terminal color methods on strings
      #
      # @safety
      #   This cop's autocorrection is unsafe because it replaces colorize gem
      #   methods with Paint gem methods. If the Paint gem is not included in the
      #   project's dependencies, the corrected code will fail at runtime with a
      #   NameError (uninitialized constant Paint).
      #
      # @example
      #
      #   # bad
      #   "string".cyan
      #   "string".red
      #   "string".green
      #   str = "hello"
      #   str.cyan
      #   "string".colorize(:blue)
      #   "string".colorize(:color => :blue)
      #   "string".colorize(:color => :blue, :background => :red)
      #   "string".blue.on_red
      #   "string".colorize(:blue).on_red
      #   "string".blue.underline
      #
      #   # good
      #   "string"
      #
      #   # if color is needed, use `paint` gem
      #   Paint["string", :cyan]
      #   Paint["string", :red]
      #   Paint["string", :green]
      #   Paint[str, :cyan]
      #   Paint["string", :blue]
      #   Paint["string", :blue, :red]
      #
      class UsePaintNotColorize < Base
        extend AutoCorrector

        # Common terminal color methods that should be prevented
        COLOR_METHODS = Set.new(
          %i[
            black
            red
            green
            yellow
            blue
            magenta
            cyan
            white
            light_black
            light_red
            light_green
            light_yellow
            light_blue
            light_magenta
            light_cyan
            light_white
            colorize
            on_black
            on_red
            on_green
            on_yellow
            on_blue
            on_magenta
            on_cyan
            on_white
            on_light_black
            on_light_red
            on_light_green
            on_light_yellow
            on_light_blue
            on_light_magenta
            on_light_cyan
            on_light_white
            bold
            italic
            underline
            blink
            swap
            hide
            uncolorize
          ],
        ).freeze

        # Style modifiers that are applied as additional options in Paint
        STYLE_MODIFIERS = Set.new(
          %i[
            bold
            italic
            underline
            blink
            swap
            hide
          ],
        ).freeze

        MSG = "Use Paint instead of colorize for terminal colors."
        PROHIBITED_CLASS = "String"
        RESTRICT_ON_SEND = COLOR_METHODS

        def on_send(node)
          return unless node.receiver
          return unless string_or_colorized_receiver?(node.receiver)

          add_offense(node) do |corrector|
            corrector.replace(node, correction(node))
          end
        end

        def on_csend(node)
          return unless string_or_colorized_receiver?(node.receiver)

          add_offense(node) # no autocorrection for safe navigation due to chained calls
        end

        private def string_or_colorized_receiver?(node)
          string_receiver?(node) || colorized_string?(node)
        end

        private def string_receiver?(node)
          node.type?(:str, :dstr) || node.variable?
        end

        private def colorized_string?(node)
          node.send_type? &&
            node.receiver.is_a?(RuboCop::AST::Node) &&
            string_or_colorized_receiver?(node.receiver)
        end

        private def correction(node)
          # Find the original string and all color/style operations in the chain
          original_string, color_ops = extract_string_and_operations(node)
          foreground = nil
          background = nil
          styles = []

          # Process all the operations to build the Paint parameters
          color_ops.each do |op|
            result = process_color_op(op)
            return "Paint.unpaint(#{original_string.source})" if result == :unpaint
            break if result == :uncorrectable

            foreground = result[:foreground] if result.key?(:foreground)
            background = result[:background] if result.key?(:background)
            styles.concat(result[:styles]) if result.key?(:styles)
          end

          return unless foreground || background || styles.any?

          # Build the Paint call
          build_paint_call(original_string, foreground, background, styles)
        end

        private def process_color_op(color_op)
          method_name = color_op[:method]
          case method_name
          when :uncolorize then :unpaint # convert to Paint.unpaint
          when :colorize   then process_colorize(color_op[:args])
          else                  process_direct_color(method_name)
          end
        end

        private def process_colorize(args)
          if args.length == 1 && args.first.sym_type?
            # Single symbol argument, like colorize(:red)
            { foreground: ":#{args.first.value}" }
          elsif args.length == 1 && args.first.hash_type?
            # Hash argument, like colorize(color: :red, background: :blue)
            extract_colorize_hash_params(args.first.pairs)
          else
            # if the argument is not a symbol or hash, we can't handle it
            :uncorrectable
          end
        end

        private def extract_colorize_hash_params(pairs)
          result = {}
          pairs.each do |pair|
            break unless pair.value.sym_type? # can't handle non-symbol arguments

            value = ":#{pair.value.value}"
            case pair.key.value
            when :color      then result[:foreground] = value
            when :background then result[:background] = value
            when :mode       then (result[:styles] ||= []) << value
            else break # unknown key, skip the rest of the hash
            end
          end
          result
        end

        private def process_direct_color(method_name)
          method_str = method_name.to_s
          if method_str.start_with?("on_")
            # Background color
            { background: ":#{method_str.delete_prefix('on_')}" }
          elsif STYLE_MODIFIERS.include?(method_name)
            # Style modifier
            { styles: [":#{method_name}"] }
          elsif method_str.start_with?("light_")
            # Light/bright foreground color
            { foreground: ":bright, :#{method_str.delete_prefix('light_')}" }
          else
            # Regular foreground color
            { foreground: ":#{method_name}" }
          end
        end

        private def extract_string_and_operations(node)
          operations = []
          current = node

          # Find the deepest operation in the chain
          while current.send_type? && COLOR_METHODS.include?(current.method_name)
            operations.unshift(
              {
                method: current.method_name,
                args: current.arguments,
              },
            )

            current = current.receiver
          end

          # The earliest receiver is the original string
          [current, operations]
        end

        private def build_paint_call(string_node, foreground, background, styles)
          # Use string_content for string nodes, or source for variables and other expressions
          string_expr = string_node.source

          params = [string_expr]

          # Add nil as a placeholder for foreground if we only have a background
          if background && !foreground
            params << "nil"
          elsif foreground
            params << foreground
          end

          # Add background if present
          params << background if background

          # Add any style modifiers
          params.concat(styles) unless styles.empty?

          "Paint[#{params.join(', ')}]"
        end
      end
    end
  end
end
