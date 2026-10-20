# 0107: A scene from a directory

Status: landed (2026-10-20, 7722fa1)

Goal: the app shoots a scene and meshes read from disk at run time, so each step of the smelter's finish can be inspected without embedding it as a demo first (user, 2026-10-20: "start over from the original 1.4M base model, and take one step at a time and check the result").

Verify:
- `./build.sh check`, `./build.sh test`; a shot of the parts scene copied under `tmp/` matches the embedded demo's.

## Specification

- `src/app/disk_demo.odin`: `demo_from_directory(directory)`; `--scene-directory <dir>` in `src/app/main.odin` overrides `--demo`; `doc/build.md`.
