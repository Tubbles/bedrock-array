#!/usr/bin/env bash
# Check or test the engine. See doc/build.md.
#   ./build.sh [check]   odin check src/engine -no-entry-point -vet
#                        -strict-style (default)
#   ./build.sh test      odin test src/engine -all-packages -vet -strict-style,
#                        so the tests of the packages under src/engine/ run too
set -euo pipefail

odin="${ODIN:-$HOME/opt/odin/odin}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-check}"

cd "$repository_root"

# The build stamp: the short commit, "+dirty" with uncommitted changes.
# An archive build has no .git and passes the commit in
# BEDROCK_ARRAY_COMMIT.
build_commit() {
	if [ -n "${BEDROCK_ARRAY_COMMIT:-}" ]; then
		printf '%s' "$BEDROCK_ARRAY_COMMIT"
		return
	fi
	local commit
	commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
	if [ "$commit" != unknown ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
		commit="$commit+dirty"
	fi
	printf '%s' "$commit"
}

# Commit and UTC build time in one define, so an all digit commit is
# never read as a number.
build_info="$(build_commit) $(date -u +%Y-%m-%dT%H:%MZ)"

case "$mode" in
	check) "$odin" check src/engine -no-entry-point -vet -strict-style -define:BUILD_INFO="$build_info" ;;
	test) "$odin" test src/engine -all-packages -vet -strict-style -define:BUILD_INFO="$build_info" ;;
	*)
		echo "usage: $0 [check|test]" >&2
		exit 2
		;;
esac
