# 0001: The build script and an empty engine package

Status: landed (2026-10-18, 59f3db4)

Goal: `build.sh` with `check` and `test` over `src/engine/`, holding one package with one test, and `doc/build.md` describing it. The shape of Mine oh Belowed's `build.sh` without its commands for other platforms.

Verify:
- `./build.sh check` and `./build.sh test` pass.

## Specification (main agent, 2026-10-18)

The shape of Mine oh Belowed's `build.sh` (`~/dev/mine-oh-belowed/build.sh`: `set -euo pipefail`, `odin="${ODIN:-$HOME/opt/odin/odin}"`, `repository_root` from `BASH_SOURCE`, `cd` there, a `build_commit` function, one `case` over the first argument) without its Windows, Android, shims, collection and bench parts. No `shared/` exists yet, so no collection flag.

- `build.sh` (new, executable). Header comment listing the commands. `build_commit`: `BEDROCK_ARRAY_COMMIT` from the environment when set (archive builds without `.git` pass it), else `git rev-parse --short HEAD` or `unknown`, with `+dirty` appended when `git status --porcelain` prints anything. `build_info` = `"$(build_commit) $(date -u +%Y-%m-%dT%H:%MZ)"`. Commands: `check` (the default) runs `"$odin" check src/engine -vet -strict-style -define:BUILD_INFO="$build_info"`; `test` runs `"$odin" test src/engine -all-packages -vet -strict-style -define:BUILD_INFO="$build_info"`; anything else prints a usage line to stderr and exits 2.
- `src/engine/build_stamp.odin` (new): `package engine`. `BUILD_INFO :: #config(BUILD_INFO, "unknown")`. `Build_Stamp :: struct { commit: string, built_at: string }`. `build_stamp :: proc(info := BUILD_INFO) -> Build_Stamp`: the text before the first space is the commit, the text after it the build time, no space means the whole text is the commit and the time is empty. Pure, `core:strings` only.
- `src/engine/build_stamp_test.odin` (new): `test_build_stamp_splits_commit_and_time` (`"a1b2c3d+dirty 2026-10-18T12:00Z"` gives `a1b2c3d+dirty` and `2026-10-18T12:00Z`) and `test_build_stamp_without_time_is_the_commit` (`"unknown"` gives `unknown` and `""`), with `testing.expect_value`.
- `doc/build.md` (new): title `# Build`, one line on what the file covers, then the sections `## The host toolchain` (Odin at `~/opt/odin`, `ODIN` overrides the path, nothing else installed yet), `## build.sh` (a table of the two commands and what they run), `## The build stamp` (the define, the `+dirty` rule, the environment override and why: an archive build has no `.git`). Markdown is not reflowed, one paragraph per line.

Verify: `./build.sh check` and `./build.sh test` pass, the test run reports the two tests.
