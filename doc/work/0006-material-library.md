# 0006: The material library

Status: todo (2026-10-18)

Goal: `data/materials/library.sjson` with the first presets (painted steel, bare alloy, copper, glass, rubber, concrete) as albedo, roughness, metallic and emissive, and `src/engine/material.odin` (package `engine`) parsing it with `core:encoding/json` as SJSON into a `Material_Library`, strict on unknown keys and ranges. The demos embed the file with `#load`. DESIGN.md, Consistency comes from the renderer.

Verify:
- `./build.sh test` passes with tests that parse the shipped file, reject an unknown key and a roughness out of range.
