# Build

How the engine is checked and tested, the demos are built for the browser and the app is built natively: the toolchain, the commands of `build.sh` and the build stamp they pass.

## The host toolchain

Odin at `~/opt/odin` (the dev-2026-09 nightly). The environment variable `ODIN` overrides the path to the compiler. Browser builds link with `wasm-ld`, which the link step calls from `PATH`. When `wasm-ld` is missing, `build.sh` wraps the Rust toolchain's `rust-lld` (`-flavor wasm`) in `tmp/linker-shims/wasm-ld` and puts that directory first on `PATH`, so lld or rustup is the one extra requirement. The native smoke run needs `xvfb-run`. glslang (the Homebrew formula `glslang`, its `glslangValidator` command) is optional: without it `./build.sh check` skips the shader validation with a note.

## build.sh

| Command | Runs |
| --- | --- |
| `./build.sh check` (the default) | `odin check src/engine -no-entry-point -vet -strict-style` with the build stamp define (the engine is a library package without `main`), the same check of the engine again for `-target:js_wasm32` so it compiles for both targets (test files carry `#+build !js`, since `core:testing` does not compile for the browser), then `odin check src/app -collection:shared=shared -vet -strict-style` with the build stamp define, then `odin check` of every `src/demos/*/` for `-target:js_wasm32`, then every shader under `src/engine/shaders/` is validated with `glslangValidator`, as it is and once more as a temporary copy whose first line is `#version 330 core`, the desktop profile the native build swaps in |
| `./build.sh test` | `odin test src/engine -all-packages -vet -strict-style` with the build stamp define, so the tests of the packages under `src/engine/` run too, then `odin test src/app -vet -strict-style` with the collection, the linker shims and the build stamp define |
| `./build.sh web <demo>` | builds `src/demos/<demo>` for the browser, see [The web build](#the-web-build) |
| `./build.sh debug` | builds `src/app` to `build/bedrock-array` with `-debug`, see [The native build](#the-native-build) |
| `./build.sh release` | the same build with `-o:speed` |
| `./build.sh smoke` | the debug build, then three frames of it under `xvfb-run`, failing on a printed `glGetError() returned` line |

Any other argument prints the usage to stderr and exits with status 2.

## The build stamp

The engine and the native commands pass `-define:BUILD_INFO="<commit> <UTC time>"`, for example `a1b2c3d+dirty 2026-10-18T12:00Z`, read by `build_stamp` in `src/engine/build_stamp.odin` and by `BUILD_INFO` in `src/app/main.odin`. The demo commands do not pass it yet: no demo shows the stamp, and Odin warns on an unused define. The commit and the time share one define so an all digit commit is never read as a number. The commit is `git rev-parse --short HEAD`, with `+dirty` appended when `git status --porcelain` prints anything, and `unknown` outside a repository. `BEDROCK_ARRAY_COMMIT` in the environment overrides it: an archive build has no `.git`, so the script building it passes the commit it was made from.

## The web build

`./build.sh web <demo>` runs `odin build src/demos/<demo> -target:js_wasm32 -vet -strict-style` and writes `build/web/<demo>/`: `index.html`, `demo.wasm`, `odin.js` (the toolchain's runtime from `core/sys/wasm/js/odin.js`), `style.css` and `labels.js`, a copy of `web/labels.js`, which starts the wasm in place of a bare `runWasm` call and moves the scene's label plaques each frame. `index.html` is `web/index.html` with every `__DEMO__` replaced by the demo's name, `style.css` a copy of `web/style.css`. Without a demo name, or with a name that has no `src/demos/<demo>/`, the command prints the usage and exits with status 2. `./build.sh check` checks every demo for the same target with the same flags.

`odin.js` fetches the wasm, so a page opened as `file://` does not run. To view a build locally: `python3 -m http.server --directory build/web/<demo> 8000`, then `http://localhost:8000/`.

## The native build

`./build.sh debug` and `./build.sh release` run `odin build src/app -out:build/bedrock-array -collection:shared=shared -vet -strict-style` with the build stamp define and `-debug` or `-o:speed`. raylib 6.0 comes from the `shared:raylib` collection, a copy of the toolchain's binding with an archive built from source ([shared/raylib/README.md](../shared/raylib/README.md) holds the why and the build record). The archive links X11, and Bazzite ships `libX11.so.6` and `libSDL3.so.0` without the unversioned development links the linker looks for, so the build creates `tmp/linker-shims/libX11.so` and `libSDL3.so` as symlinks to them and passes `-extra-linker-flags` pointing the linker at `tmp/linker-shims`.

The binary shows one scene demo first person, the scenes and their data embedded by `src/app/demos.odin`, with the mouse and the keys of the pages ([render.md](render.md), Scene files), and Escape quits. It takes `--demo <name>`, one of `light`, `surface`, `cave` and `models` (the default), `--frames <n>`, which stops after n frames (0, the default, runs until the window closes or Escape), and `--windowed`, which keeps the 1280 by 720 window and the cursor instead of going borderless over the monitor with the cursor captured. Any other argument or an unknown demo prints the usage and exits with status 2. When the window does not open or the scene does not load it exits with status 1 and a line on stderr. After the window opens it loads OpenGL 3.3 through GLFW's `glfwGetProcAddress`, so it links no libGL, and prints the GL vendor, renderer and version. After the first frame it reads `glGetError` once and on an error prints `gl error 0x...` on stderr and exits with status 1.

`./build.sh smoke` runs the debug build as `xvfb-run -a -s "-screen 0 1280x720x24" env XDG_SESSION_TYPE=x11 build/bedrock-array --frames 3`, so a link or window problem shows in a headless session and not on the couch. The run fails on a printed `glGetError() returned` line: the debug build's GL binding drains every error right after the call that raised it and prints it, so the app's own one shot check only sees errors in the release build.

## Writing a demo

A demo is one package under `src/demos/<name>/`. `odin.js` runs its `main` once at load, then calls the exported `step :: proc(delta_time: f64) -> bool` every animation frame for as long as it returns true. Rendering goes through `vendor:wasm/WebGL` with WebGL2 calls only, never WebGL1 (CLAUDE.md, Stack). Input from `core:sys/wasm/js`: the `.Pointer_Down` event covers touch and mouse alike, so one listener serves the phone and the laptop. A scene demo is the engine's `Scene_Page` plus its scene file `data/demos/<name>/scene.sjson`, passed with `#load` to `scene_page_init` with the material library ([render.md](render.md), Scene files, holds the format), and the texture directory `data/materials/textures/` through `#load_directory`. The page brings the orbit input: drag, pinch and wheel.

## Installing the demos

`tools/install_web_build.sh [commit]` builds every demo of the commit (default `HEAD`) and installs the pages under `bin/web/`. It builds from a `git archive` of the commit in a temporary directory, so the working tree is never served and agents editing `src/` cannot break a page that is open. The archive has no `.git`, so the script passes the commit in `BEDROCK_ARRAY_COMMIT` for the build stamp. Each install goes to its own `bin/web/builds/<UTC time>-<commit>/` with an `index.html` at its root that links every demo and names the commit and the build time. One rename switches the `bin/web/current` link to it, so the server never finds the link missing, and the two newest builds stay (double buffering). Run it after every commit on `main`.

## The web host

`tools/bedrock-array-web.service` is a systemd user unit that serves `bin/web/current` with `python3 -m http.server` on port 8080, bound to every address. Enable it once, from the repository root: `ln -sfn "$PWD/tools/bedrock-array-web.service" ~/.config/systemd/user/`, then `systemctl --user daemon-reload`, then `systemctl --user enable --now bedrock-array-web.service`. The pages are at `http://192.168.1.7:8080/`, or `http://bazzite:8080/` where the name resolves. The firewalld zone (FedoraWorkstation) already opens TCP 1025 to 65535, so the port needs no firewall change. A user service runs while the user is logged in. `loginctl enable-linger` would keep it up without a login.

## Large files

Binaries under the extensions `.gitattributes` lists (images, audio, models, fonts) are Git LFS objects on GitHub, text formats stay plain (DESIGN.md, Asset storage). `.gitattributes` is the one place the routing lives.

A fresh clone needs `git lfs install` once per machine (git-lfs from Homebrew here), then checkout fetches the objects.

Every fetch counts against the LFS bandwidth quota, so CI caches its LFS objects between runs and the Deck receives copies of the built tree, never a clone.
