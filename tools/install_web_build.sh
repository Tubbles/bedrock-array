#!/usr/bin/env bash
# Install the demo pages the web host serves: every demo of a commit (HEAD,
# or the commit argument), built from a git archive into its own directory
# under bin/web/builds/ with an index page, then pointed at by the
# bin/web/current link, which tools/bedrock-array-web.service serves. The
# working tree is never served, so agents editing src/ cannot break a page
# a phone has open. The two newest builds stay (double buffering), older
# ones go. Run it after every commit that lands on main. See doc/build.md.
set -euo pipefail

usage() {
	cat <<'USAGE'
usage: tools/install_web_build.sh [commit]

Builds every demo of the commit (default HEAD) for the browser from a git
archive and installs the pages under bin/web/.
USAGE
}

ref=HEAD
case "${1:-}" in
	-h | --help)
		usage
		exit 0
		;;
	-*)
		usage >&2
		exit 2
		;;
	"") ;;
	*) ref="$1" ;;
esac

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
web_root="$repository_root/bin/web"
commit="$(git -C "$repository_root" rev-parse --short "$ref")"
# Sorts by install time, so the newest is last.
build_name="$(date -u +%Y%m%dT%H%M%SZ)-$commit"
keep_count=2
staging="$(mktemp -d "${TMPDIR:-/tmp}/bedrock-array-web.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

# One rename switches the link, so the server never finds it missing.
# Arguments: the web directory, the build's name.
switch_current_build() {
	ln -sfn "builds/$2" "$1/current.new"
	mv -Tf "$1/current.new" "$1/current"
}

# Older builds go. Arguments: the web directory, the builds to keep.
remove_old_builds() {
	find "$1/builds" -mindepth 1 -maxdepth 1 -type d | sort -r | tail -n +$(($2 + 1)) | while read -r old_build; do
		rm -rf "$old_build"
	done
}

# The index page listing the demos. Arguments: the file to write, then the
# demo names.
write_index() {
	local index_file="$1"
	shift
	local links="" demo
	for demo in "$@"; do
		links+="<a href=\"$demo/\">$demo</a>"$'\n'
	done
	cat > "$index_file" <<INDEX
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bedrock Array demos</title>
<style>
body { margin: 0; padding: 24px 16px; background: #111; color: #ddd; font-family: sans-serif; }
h1 { font-size: 1.6rem; font-weight: normal; }
a { display: block; padding: 12px 0; font-size: 2rem; color: #9cf; text-decoration: none; }
footer { margin-top: 32px; font-size: 0.9rem; color: #888; }
</style>
</head>
<body>
<h1>Bedrock Array demos</h1>
${links}<footer>commit $commit, built $(date -u +%Y-%m-%dT%H:%MZ)</footer>
</body>
</html>
INDEX
}

git -C "$repository_root" archive --format=tar "$ref" | tar -x -C "$staging"
# The archive has no .git, so the stamp gets the commit from here.
export BEDROCK_ARRAY_COMMIT="$commit"
demos=()
for directory in "$staging"/src/demos/*/; do
	[ -d "$directory" ] || continue
	demos+=("$(basename "$directory")")
done
for demo in "${demos[@]}"; do
	(cd "$staging" && ./build.sh web "$demo")
done

mkdir -p "$web_root/builds"
# The trailing dot copies the contents, so a build name that already
# exists (two installs within one second) is filled, not nested into.
mkdir -p "$web_root/builds/$build_name"
cp -r "$staging/build/web/." "$web_root/builds/$build_name"
write_index "$web_root/builds/$build_name/index.html" "${demos[@]}"
switch_current_build "$web_root" "$build_name"
remove_old_builds "$web_root" "$keep_count"

echo "installed $build_name, http://$(hostname -I | awk '{print $1}'):8080/"
