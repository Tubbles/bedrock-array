#!/usr/bin/env bash
# Renders one frame of a demo to a PNG without a display. See doc/build.md.
#   tools/shoot.sh <demo> <out.png> [app arguments ...]
# Builds the debug app unless build/bedrock-array is newer than every
# file under src/ and data/, then runs it under xvfb-run with
# --windowed --demo <demo> --shot <out.png> and the rest.
set -euo pipefail

if [ "$#" -lt 2 ]; then
	echo "usage: $0 <demo> <out.png> [app arguments ...]" >&2
	exit 2
fi
demo="$1"
output="$2"
shift 2
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$repository_root/build/bedrock-array"

if [ ! -x "$app" ] || [ -n "$(find "$repository_root/src" "$repository_root/data" -type f -newer "$app" -print -quit)" ]; then
	"$repository_root/build.sh" debug
fi
mkdir -p "$(dirname "$output")"
xvfb-run -a -s "-screen 0 1280x720x24" env XDG_SESSION_TYPE=x11 "$app" --windowed --demo "$demo" --shot "$output" "$@"
