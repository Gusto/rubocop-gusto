#!/bin/bash

commit_msg_file="$1"
commit_msg=$(head -1 "$commit_msg_file")

# Allow merge commits and fixup/squash commits
if echo "$commit_msg" | grep -qE "^(Merge |fixup! |squash! )"; then
  exit 0
fi

pattern="^(feat|fix|chore|docs|refactor|perf|test|ci|build|revert)(\(.+\))?(!)?: .+"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
  echo ""
  echo "ERROR: Commit message does not follow Conventional Commits format."
  echo ""
  echo "Expected: <type>(<optional scope>): <description>"
  echo ""
  echo "Examples:"
  echo "  feat: add new cop for factory usage"
  echo "  fix: correct false positive in DefaultScope cop"
  echo "  chore: update rubocop dependency"
  echo "  feat(cops): add Gusto/DiscouragedGem cop"
  echo "  feat!: drop support for Ruby 3.1"
  echo ""
  echo "Allowed types: feat, fix, chore, docs, refactor, perf, test, ci, build, revert"
  echo ""
  exit 1
fi
