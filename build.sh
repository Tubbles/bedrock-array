#!/usr/bin/env bash
# Check, test, build natively or build for the web. See doc/build.md.
#   ./build.sh [check]   odin check src/engine -no-entry-point -vet
#                        -strict-style (default), natively and again for
#                        -target:js_wasm32, then src/app natively, then
#                        every src/demos/*/ for -target:js_wasm32, then
#                        every src/engine/shaders/ file with glslangValidator,
#                        as it is and with "#version 330 core" for its version line
#   ./build.sh test      odin test src/engine -all-packages -vet -strict-style,
#                        so the tests of the packages under src/engine/ run too,
#                        then odin test src/app with the app's flags
#   ./build.sh web <demo>
#                        builds src/demos/<demo> to build/web/<demo>/ with
#                        odin.js and the page shell from web/
#   ./build.sh debug     builds src/app to build/bedrock-array with -debug
#   ./build.sh release   builds src/app to build/bedrock-array with -o:speed
#   ./build.sh smoke     debug build, then three frames of the menu and three
#                        of the models demo under xvfb-run
set -euo pipefail

odin="${ODIN:-$HOME/opt/odin/odin}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-check}"
odin_root="$(dirname "$odin")"
odin_js="$odin_root/core/sys/wasm/js/odin.js"
usage="usage: $0 [check|test|web <demo>|debug|release|smoke]"
app_output="build/bedrock-array"
shim_directory="$repository_root/tmp/linker-shims"
collection="-collection:shared=shared"

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

# Parse every shader for the stage its extension names, as it is and
# once more with a leading "#version 300 es" line swapped for
# "#version 330 core", the swap the native build makes at load.
# glslang is optional: without it the check goes on with a note.
validate_shaders() {
	if ! command -v glslangValidator >/dev/null; then
		echo "shader validation skipped: glslangValidator not found (brew install glslang)" >&2
		return 0
	fi
	local file desktop_directory failed=0
	desktop_directory="$(mktemp -d)"
	for file in src/engine/shaders/*.vert src/engine/shaders/*.frag; do
		[ -f "$file" ] || continue
		glslangValidator "$file" || failed=1
		# The copy keeps the extension, which names the stage.
		sed "1s/^#version 300 es$/#version 330 core/" "$file" > "$desktop_directory/$(basename "$file")"
		glslangValidator "$desktop_directory/$(basename "$file")" || failed=1
	done
	rm -rf "$desktop_directory"
	if [ "$failed" -ne 0 ]; then
		exit 1
	fi
}

# Bazzite ships runtime libraries without the unversioned development
# symlinks the linker looks for, so point it at a directory of our own.
create_linker_shims() {
	mkdir -p "$shim_directory"
	ln -sfn /usr/lib64/libX11.so.6 "$shim_directory/libX11.so"
	ln -sfn /usr/lib64/libSDL3.so.0 "$shim_directory/libSDL3.so"
}

# The native app, with the optimisation flag as the argument.
build_app() {
	create_linker_shims
	mkdir -p "$(dirname "$app_output")"
	"$odin" build src/app -out:"$app_output" "$collection" -vet -strict-style \
		-define:BUILD_INFO="$build_info" -extra-linker-flags:"-L$shim_directory" "$1"
}

# One run of three frames under a virtual X server with the given
# arguments, so a link or window problem shows without opening a window.
# The debug build's GL binding drains every error right after the call
# that raised it and prints it, so the app's own check never sees one
# there: the run fails on the printed line as well as on a non zero exit.
smoke_run() {
	local output status=0
	output="$(xvfb-run -a -s "-screen 0 1280x720x24" env XDG_SESSION_TYPE=x11 "$app_output" "$@" 2>&1)" || status=$?
	printf '%s\n' "$output"
	if [ "$status" -ne 0 ]; then
		return "$status"
	fi
	if printf '%s\n' "$output" | grep -q "glGetError() returned"; then
		echo "smoke: the run raised GL errors" >&2
		return 1
	fi
}

smoke_app() {
	build_app -debug
	smoke_run --frames 3
	smoke_run --demo models --frames 3
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
	cp web/labels.js "$out/labels.js"
	cp web/pointer_lock.js "$out/pointer_lock.js"
}

case "$mode" in
	check)
		"$odin" check src/engine -no-entry-point -vet -strict-style -define:BUILD_INFO="$build_info"
		"$odin" check src/engine -no-entry-point -target:js_wasm32 -vet -strict-style -define:BUILD_INFO="$build_info"
		"$odin" check src/app "$collection" -vet -strict-style -define:BUILD_INFO="$build_info"
		check_demos
		validate_shaders
		;;
	test)
		"$odin" test src/engine -all-packages -vet -strict-style -define:BUILD_INFO="$build_info"
		create_linker_shims
		"$odin" test src/app "$collection" -vet -strict-style -define:BUILD_INFO="$build_info" -extra-linker-flags:"-L$shim_directory"
		;;
	web)
		ensure_wasm_linker
		build_web "${2:-}"
		;;
	debug) build_app -debug ;;
	release) build_app -o:speed ;;
	smoke) smoke_app ;;
	*)
		echo "$usage" >&2
		exit 2
		;;
esac
