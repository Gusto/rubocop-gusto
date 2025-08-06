#!/usr/bin/env bash
# Port of https://github.com/pre-commit/pre-commit-hooks/blob/main/pre_commit_hooks/no_commit_to_branch.py to bash
package=lefthook/no_commit_to_branch.sh
protected=

show_help() {
  echo "$package - check if commit to branch is allowed"
  echo "$package [options]"
  echo
  echo "options:"
  echo "-h, --help                show brief help"
  echo "-b, --branch=BRANCH       specify branch to protect"
}
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -b|--branch)
      shift
      protected=$1
      shift
      ;;
    *)
      echo "Unexpected argument $1"
      echo
      show_help
      exit 1
      ;;
  esac
done

branch=$(git symbolic-ref HEAD)

if [[ -z "$protected" ]]; then
  echo "--branch is required"
  exit 1
fi

if [[ "$branch" == "refs/heads/$protected" ]]; then
  echo "Whoops, looks like you are trying to commit to a protected branch! ($protected)"
  exit 1
fi
