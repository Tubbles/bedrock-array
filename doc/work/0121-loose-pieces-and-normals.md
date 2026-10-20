# 0121: Loose pieces and normals as steps

Status: designed (2026-10-20)

Goal: two cleanup ops of the finish chain (doc/workflows/models.md, the finish step): `delete_loose` removes connected pieces of fewer than `triangles` triangles (generator debris), `normals` recomputes the normals smooth by `angle` degrees, weighted by face area, so every later step and the export start from clean shading (user, 2026-10-20: "ALL THE STEPS from base model TO THE ONE GOING INTO THE GAME").

Verify:
- `./build.sh test` with tests of both ops; the smelter's pipeline with both runs, and the editor's line shows their machines.

## Specification

- `src/pipeline/pipeline_steps.odin`: `step_delete_loose(mesh, triangles, within_part)` (connected components over shared vertices after the weld), `step_normals(mesh, angle)` (vertices split where the face normals differ by more than the angle, each normal the area weighted mean of its faces); both new geometry. Parse, save and the editor's key panel know them (`OP_KEYS`, the default step, the hints of 0118 when it has landed).
- `doc/workflows/pipeline_editor.md`: the two rows of the op table.
