# 0112: The pipeline file and its runner

Status: implementing (2026-10-20)

Goal: `pipeline.sjson` parsed into steps, run in order with every step's output cached, rerun from an edited step, the heavy steps on a worker thread through the existing tools, saved back.

Verify:
- `./build.sh test` with the new tests; a small pipeline file with every native op runs and its outputs match the step procedures; `pipeline_save` and parse round trip.

## Specification

- `src/pipeline/pipeline_file.odin`: `Step {op: Op, enabled: bool, note: string, front, height, metres, part, technique, trim, triangles, from, to, turn, select}`, `Pipeline {source: string, steps: [dynamic]Step}`, `pipeline_parse(data) -> (Pipeline, problem)` (SJSON, strict keys per op, errors with the step index), `pipeline_save(pipeline) -> string` (SJSON in the format of the doc, one step per line group).
- `src/pipeline/pipeline_run.odin`: `Run {pipeline, outputs: [dynamic]Pipeline_Mesh, status: [dynamic]Step_Status (Stale, Running, Done, Failed with a message), worker thread state}`, `run_from(run, index)` (marks steps from index stale and runs the native ones at once), `run_poll(run)` (called each frame: starts the next heavy step on a `core:thread` worker, collects a finished one), heavy steps write PLY per part under `work/models/<id>/pipeline/step<n>/`, run `flatpak run org.blender.Blender -b --python <abs>/tools/models/decimate.py -- ...` per part with each part's share of `triangles`, or `tools/models/reconstruct.py <ply> <out.ply> --technique poisson --cell 0.0025 --trim <trim>` (`fill` through `close.py`) for `close`, through `os.process_exec`, and read the results back with 0111's readers. A failed tool sets Failed with its stderr's last line.
- `run_export(run)`: the last done step's mesh through `write_part_blobs` to `data/demos/parts/meshes/`.
- Tests: `test_parse_every_op`, `test_parse_rejects_an_unknown_key`, `test_save_round_trips`, `test_run_native_steps_in_order`, `test_rerun_from_keeps_earlier_outputs`.
