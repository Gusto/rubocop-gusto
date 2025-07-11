# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module Gusto
    # A plugin that integrates Gusto's standard RuboCop cops and rules.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: 'rubocop-gusto',
          version: RuboCop::Gusto::VERSION,
          homepage: 'https://github.com/Gusto/rubocop-gusto',
          description: "A collection of Gusto's standard RuboCop cops and rules."
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        project_root = Pathname.new(__dir__).join('../../..')

        LintRoller::Rules.new(type: :path, config_format: :rubocop, value: project_root.join('config', 'default.yml'))
      end
    end
  end
end
