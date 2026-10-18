#!/usr/bin/env bash
# Check, test or build for the web. See doc/build.md.
#   ./build.sh [check]   odin check src/engine -no-entry-point -vet
#                        -strict-style (default), then every src/demos/*/
#                        for -target:js_wasm32
#   ./build.sh test      odin test src/engine -all-packages -vet -strict-style,
#                        so the tests of the packages under src/engine/ run too
#   ./build.sh web <demo>
#                        builds src/demos/<demo> to build/web/<demo>/ with
#                        odin.js and the page shell from web/
set -euo pipefail

odin="${ODIN:-$HOME/opt/odin/odin}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-check}"
odin_root="$(dirname "$odin")"
odin_js="$odin_root/core/sys/wasm/js/odin.js"
usage="usage: $0 [check|test|web <demo>]"

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
# The stamp define returns here when a demo shows the build stamp.
web_flags=(-target:js_wasm32 -vet -strict-style)

# Browser builds link with wasm-ld. Without one on PATH, wrap the Rust
# toolchain's rust-lld (-flavor wasm) in tmp/linker-shims/.
ensure_wasm_linker() {
	if command -v wasm-ld >/dev/null; then
		return
	fi
	local rust_lld=""
	if command -v rustc >/dev/null; then
		local sysroot host
		sysroot="$(rustc --print sysroot 2>/dev/null)" || sysroot=""
		host="$(rustc -vV 2>/dev/null | sed -n 's/^host: //p')" || host=""
		rust_lld="$sysroot/lib/rustlib/$host/bin/rust-lld"
	fi
	if [ -z "$rust_lld" ] || [ ! -x "$rust_lld" ]; then
		echo "browser builds need wasm-ld: install lld or a Rust toolchain" >&2
		exit 1
	fi
	local shims="$repository_root/tmp/linker-shims"
	mkdir -p "$shims"
	printf '#!/usr/bin/env bash\nexec "%s" -flavor wasm "$@"\n' "$rust_lld" > "$shims/wasm-ld"
	chmod +x "$shims/wasm-ld"
	PATH="$shims:$PATH"
}

check_demos() {
	local directory
	for directory in src/demos/*/; do
		[ -d "$directory" ] || continue
		"$odin" check "$directory" "${web_flags[@]}"
	done
}

build_web() {
	local demo="${1:-}"
	if [ -z "$demo" ] || [ ! -d "src/demos/$demo" ]; then
		echo "$usage" >&2
		exit 2
	fi
	local out="build/web/$demo"
	mkdir -p "$out"
	"$odin" build "src/demos/$demo" -out:"$out/demo.wasm" "${web_flags[@]}"
	cp "$odin_js" "$out/odin.js"
	sed "s/__DEMO__/$demo/g" web/index.html > "$out/index.html"
	cp web/style.css "$out/style.css"
}

case "$mode" in
	check)
		"$odin" check src/engine -no-entry-point -vet -strict-style -define:BUILD_INFO="$build_info"
		check_demos
		;;
	test) "$odin" test src/engine -all-packages -vet -strict-style -define:BUILD_INFO="$build_info" ;;
	web)
		ensure_wasm_linker
		build_web "${2:-}"
		;;
	*)
		echo "$usage" >&2
		exit 2
		;;
esac
