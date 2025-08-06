# Common functions + config for all hook scripts
autofix=""

if [[ -n "$ZP_COMMITTER_FIX" ]]; then
  echo "AUTOFIX via $ZP_COMMITTER_FIX $ZP_COMMITTER_FIX"
  autofix=1
fi

case "${LEFTHOOK_AUTO_FIX:-}" in
true | 1 | T | t)
	echo "AUTOFIX via LEFTHOOK_AUTO_FIX $LEFTHOOK_AUTO_FIX"
	autofix=1
	;;
esac

if [[ "$LEFTHOOK_VERBOSE" = "1" ]]; then
  echo "ARGV: $*"
fi

while test $# -gt 0; do
  case "$1" in
    -a|--autocorrect|-f|--fix)
      echo "AUTOFIX via $1"
      autofix=1

      shift
      ;;
    *)
      break
      ;;
  esac
done

if [[ "$LEFTHOOK_VERBOSE" = "1" ]]; then
  echo "AUTOFIX: $autofix"
fi
export autofix

function autofix() {
  [[ -n "$autofix" ]]
}
