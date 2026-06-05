# frozen_string_literal: true

SimpleCov.start do
  enable_coverage :branch
  # Ruby 4.0's branch-coverage instrumentation reports some branches that are in fact executed
  # (e.g. the nil-receiver path of `&.`) as uncovered -- the same code measures 100% on 3.4 but
  # 98.8% on 4.0. Skip the minimum-coverage gate on 4.0 only: the full suite still runs there (so
  # real test failures block), and strict 100% line + branch coverage stays enforced on every
  # other Ruby.
  minimum_coverage(line: 100, branch: 100) unless RUBY_VERSION.start_with?("4.0")
  add_filter "/spec/"
end
