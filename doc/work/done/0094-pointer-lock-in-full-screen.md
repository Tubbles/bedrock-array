# 0094: Pointer lock in full screen

Status: landed (2026-10-19, df8b896)

Goal: on a fly page in the browser's full screen (F11), a click locks the mouse pointer so the mouse turns without the cursor leaving the canvas (user, 2026-10-19: "can you make the fly camera lock the mouse pointer when in full screen (F11)?").

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh web light`, `./build.sh web decimation` (the page shell holds the new script, an orbit page never locks).

## Specification

- `src/engine/web_scene_page.odin`: exports `pointer_lock_wanted :: proc "contextless" () -> bool` (the page is ready and its scene's camera mode is `.Fly`) and `turn_by_mouse :: proc "contextless" (delta_x, delta_y: f32)` (adds the delta times `SCENE_PAGE_DRAG_RADIANS_PER_PIXEL` to `turn_pending`, nothing when not ready). The pointer move handler stays as it is: under a lock the client position does not change, so it adds nothing.
- New `web/pointer_lock.js`: full screen means `document.fullscreenElement` or the window covering the screen (`innerWidth >= screen.width && innerHeight >= screen.height`), since F11 is not the Fullscreen API. A primary button `pointerdown` on the canvas while full screen and `pointer_lock_wanted()` calls `canvas.requestPointerLock()`. While `document.pointerLockElement === canvas`, each `mousemove` hands `movementX` and `movementY` to `turn_by_mouse`, read in JS because the runtime stores the movement as an integer. A `resize` that leaves full screen calls `document.exitPointerLock()`. It reads the exports from the `memory` the page script already makes: expose that object as `window.bedrockMemory` in `web/labels.js`, which runs first.
- `web/index.html` loads `pointer_lock.js` after `labels.js`; `build.sh` copies it beside the others.
- `doc/render.md`: the page input sentence names the lock (click in full screen, Escape releases it, the browser's own key).
