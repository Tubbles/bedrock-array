# 0009: Headless screenshots of the demo pages

Status: todo (2026-10-18)

Goal: a command that renders a built demo page to a PNG without a display, so the main agent and the reviewers can look at what an item drew before it lands, instead of the user being the first to see it. Headless Firefox (the flatpak) returned pure black for both the hello and the light page on 2026-10-18, so the tool needs a browser whose headless mode runs WebGL2 in software and a wait until the wasm has drawn a frame.

Verify:
- `tools/screenshot_page.sh light tmp/light.png` writes a PNG of `build/web/light/` that is not a single colour (the light demo shows three lit shapes).

## Specification

Written once 0008 lands, after a short measurement of the candidates: Playwright's Chromium with its software GL, or Firefox with `webgl.force-enabled` and a software renderer in a prepared profile.
