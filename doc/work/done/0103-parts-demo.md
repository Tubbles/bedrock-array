# 0103: The parts demo

Status: landed (2026-10-19, bc0cebb)

Goal: the smelter seen with each brief part in its material, from the blobs of 0102, on the page and in the app, the first look at the finish step's result.

Verify:
- `./build.sh web parts`, `./build.sh smoke`, the app run headless with `--demo parts --frames 3`.

## Specification

- `src/demos/parts/` (a copy of the decimation package), `data/demos/parts/scene.sjson` (orbit, one mesh item per blob in the brief's material), the description, the app's menu entry, the usage line and `doc/build.md`.
