# 0002: The web build and a hello page

Status: todo (2026-10-18)

Goal: `./build.sh web <demo>` builds `src/demos/<demo>` with `-target:js_wasm32` into `build/web/<demo>/` together with the toolchain's `odin.js` and the page shell from `web/` (one HTML file, one stylesheet, a canvas that fills the viewport on a phone and a laptop). `src/demos/hello` clears a WebGL2 canvas to a colour that changes with a tap or a click. `doc/build.md` gains the web section.

Verify:
- `./build.sh web hello` produces `build/web/hello/index.html`, the wasm file and `odin.js`.
- The page opens on the phone and the laptop and the colour changes on tap and click (the user).
