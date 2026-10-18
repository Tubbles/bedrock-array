# Build

How the engine is checked and tested and the demos are built for the browser: the toolchain, the commands of `build.sh` and the build stamp they pass.

## The host toolchain

Odin at `~/opt/odin` (the dev-2026-09 nightly). The environment variable `ODIN` overrides the path to the compiler. Browser builds link with `wasm-ld`, which the link step calls from `PATH`. When `wasm-ld` is missing, `build.sh` wraps the Rust toolchain's `rust-lld` (`-flavor wasm`) in `tmp/linker-shims/wasm-ld` and puts that directory first on `PATH`, so lld or rustup is the one extra requirement. glslang (the Homebrew formula `glslang`, its `glslangValidator` command) is optional: without it `./build.sh check` skips the shader validation with a note.

## build.sh

| Command | Runs |
| --- | --- |
| `./build.sh check` (the default) | `odin check src/engine -no-entry-point -vet -strict-style` with the build stamp define (the engine is a library package without `main`), the same check of the engine again for `-target:js_wasm32` so it compiles for both targets (test files carry `#+build !js`, since `core:testing` does not compile for the browser), then `odin check` of every `src/demos/*/` for `-target:js_wasm32`, then every shader under `src/engine/shaders/` is validated with `glslangValidator` |
| `./build.sh test` | `odin test src/engine -all-packages -vet -strict-style` with the build stamp define, so the tests of the packages under `src/engine/` run too |
| `./build.sh web <demo>` | builds `src/demos/<demo>` for the browser, see [The web build](#the-web-build) |

Any other argument prints the usage to stderr and exits with status 2.

## The build stamp

The engine commands pass `-define:BUILD_INFO="<commit> <UTC time>"`, for example `a1b2c3d+dirty 2026-10-18T12:00Z`, read by `build_stamp` in `src/engine/build_stamp.odin`. The demo commands do not pass it yet: no demo shows the stamp, and Odin warns on an unused define. The commit and the time share one define so an all digit commit is never read as a number. The commit is `git rev-parse --short HEAD`, with `+dirty` appended when `git status --porcelain` prints anything, and `unknown` outside a repository. `BEDROCK_ARRAY_COMMIT` in the environment overrides it: an archive build has no `.git`, so the script building it passes the commit it was made from.

## The web build

`./build.sh web <demo>` runs `odin build src/demos/<demo> -target:js_wasm32 -vet -strict-style` and writes `build/web/<demo>/`: `index.html`, `demo.wasm`, `odin.js` (the toolchain's runtime from `core/sys/wasm/js/odin.js`) and `style.css`. `index.html` is `web/index.html` with every `__DEMO__` replaced by the demo's name, `style.css` a copy of `web/style.css`. Without a demo name, or with a name that has no `src/demos/<demo>/`, the command prints the usage and exits with status 2. `./build.sh check` checks every demo for the same target with the same flags.

`odin.js` fetches the wasm, so a page opened as `file://` does not run. To view a build locally: `python3 -m http.server --directory build/web/<demo> 8000`, then `http://localhost:8000/`.

## Writing a demo

A demo is one package under `src/demos/<name>/`. `odin.js` runs its `main` once at load, then calls the exported `step :: proc(delta_time: f64) -> bool` every animation frame for as long as it returns true. Rendering goes through `vendor:wasm/WebGL` with WebGL2 calls only, never WebGL1 (CLAUDE.md, Stack). Input from `core:sys/wasm/js`: the `.Pointer_Down` event covers touch and mouse alike, so one listener serves the phone and the laptop. A demo's scene is `data/demos/<name>/scene.sjson`, loaded with `#load` and `parse_scene` ([render.md](render.md), Scene files, holds the format).

## Installing the demos

`tools/install_web_build.sh [commit]` builds every demo of the commit (default `HEAD`) and installs the pages under `bin/web/`. It builds from a `git archive` of the commit in a temporary directory, so the working tree is never served and agents editing `src/` cannot break a page that is open. The archive has no `.git`, so the script passes the commit in `BEDROCK_ARRAY_COMMIT` for the build stamp. Each install goes to its own `bin/web/builds/<UTC time>-<commit>/` with an `index.html` at its root that links every demo and names the commit and the build time. One rename switches the `bin/web/current` link to it, so the server never finds the link missing, and the two newest builds stay (double buffering). Run it after every commit on `main`.

## The web host

`tools/bedrock-array-web.service` is a systemd user unit that serves `bin/web/current` with `python3 -m http.server` on port 8080, bound to every address. Enable it once, from the repository root: `ln -sfn "$PWD/tools/bedrock-array-web.service" ~/.config/systemd/user/`, then `systemctl --user daemon-reload`, then `systemctl --user enable --now bedrock-array-web.service`. The pages are at `http://192.168.1.7:8080/`, or `http://bazzite:8080/` where the name resolves. The firewalld zone (FedoraWorkstation) already opens TCP 1025 to 65535, so the port needs no firewall change. A user service runs while the user is logged in. `loginctl enable-linger` would keep it up without a login.

## Large files

Binaries under the extensions `.gitattributes` lists (images, audio, models, fonts) are Git LFS objects on GitHub, text formats stay plain (DESIGN.md, Asset storage). `.gitattributes` is the one place the routing lives.

A fresh clone needs `git lfs install` once per machine (git-lfs from Homebrew here), then checkout fetches the objects.

Every fetch counts against the LFS bandwidth quota, so CI caches its LFS objects between runs and the Deck receives copies of the built tree, never a clone.
