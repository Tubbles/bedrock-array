# Build

How the engine is checked and tested: the toolchain, the commands of `build.sh` and the build stamp they pass.

## The host toolchain

Odin at `~/opt/odin` (the dev-2026-09 nightly). The environment variable `ODIN` overrides the path to the compiler. Nothing else is installed yet.

## build.sh

| Command | Runs |
| --- | --- |
| `./build.sh check` (the default) | `odin check src/engine -no-entry-point -vet -strict-style` with the build stamp define (the engine is a library package without `main`) |
| `./build.sh test` | `odin test src/engine -all-packages -vet -strict-style` with the build stamp define, so the tests of the packages under `src/engine/` run too |

Any other argument prints the usage to stderr and exits with status 2.

## The build stamp

Every command passes `-define:BUILD_INFO="<commit> <UTC time>"`, for example `a1b2c3d+dirty 2026-10-18T12:00Z`, read by `build_stamp` in `src/engine/build_stamp.odin`. The commit and the time share one define so an all digit commit is never read as a number. The commit is `git rev-parse --short HEAD`, with `+dirty` appended when `git status --porcelain` prints anything, and `unknown` outside a repository. `BEDROCK_ARRAY_COMMIT` in the environment overrides it: an archive build has no `.git`, so the script building it passes the commit it was made from.
