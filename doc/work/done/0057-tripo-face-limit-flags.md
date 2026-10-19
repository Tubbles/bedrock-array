# 0057: Face limit flags on the Tripo request

Status: landed (2026-10-19, 8edbad0)

Goal: the first model came back at 1.46 million triangles against the brief's budget of 12000, and Tripo's own reduction, `face_limit` with or without `smart_low_poly`, is to be compared with Blender's decimation on the review sheet (user, 2026-10-19: "do all variants so we can compare the outputs"). The tool takes the two request fields as flags and names each variant's output apart.

Verify:
- `python3 tools/models/generate.py smelter --dry-run` prints as before, the body without `face_limit` or `smart_low_poly`, the output `work/models/smelter/model_7.glb`.
- `python3 tools/models/generate.py smelter --face-limit 12000 --dry-run` prints a body with `"face_limit": 12000` and the output `work/models/smelter/model_7_faces12000.glb`.
- `python3 tools/models/generate.py smelter --face-limit 12000 --smart-low-poly --dry-run` prints `"face_limit": 12000` and `"smart_low_poly": true` and the output `model_7_faces12000_smart.glb`; `--smart-low-poly` alone gives `model_7_smart.glb`.
- The live runs are the main agent's.

## Specification

- `tools/models/generate.py`: `--face-limit <n>` (int, default none) and `--smart-low-poly` (store_true). `submit_body(tokens, seed, face_limit, smart_low_poly)` adds `"face_limit": n` when given and `"smart_low_poly": true` when set, after `model_seed`. `output_stem(seed, face_limit, smart_low_poly)` returns `model_<seed>` plus `_faces<n>` when a limit is given plus `_smart` when set; the GLB and the sidecar use it. The sidecar gains one line `face_limit: <n or none>` and one `smart_low_poly: true|false` after `model:`. The docstring's usage line and the output name sentence follow.
- `doc/workflows/models.md`: step 1's command gains the two flags with one clause on what they are for (Tripo's own reduction, compared with Blender's on the sheet) and the output name pattern.
