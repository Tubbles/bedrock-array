# 0108: Repairs before the split

Status: landed (2026-10-20, 808c710)

Goal: the finish step's preprocess, as data: the smelter's screws that the generator modelled inside the body and the skirt are cut out into the fittings, so they get copper, and its three empty screw holes get a copy of a neighbouring screw (user, 2026-10-20: "we need to add a preprocess step right after getting the base model from tripo", "all screw holes should be populated with screws", "7 8 13 are unpopulated screw holes. The rest has screws"). The spots come from the main agent's shots and a ray cast into the raw parts (`tmp/parts/pick.py`); the user judged which are empty on a false colour sheet.

Verify:
- `python3 -m unittest discover -s tools/models -p "*_test.py"` with the new tests; `tools/models/parts.py smelter` prints one line per extraction (triangles cut, cut radius) and per addition (the source, the move); the main agent's false colour close ups of all 15 spots show a fittings coloured screw in every one, seated, and the panel around it whole.

## Specification

- `data/machines/smelter/generated.sjson`: `extractions = [ { near = [x, y, z], facing = "+z" } ... ]` and `additions = [ { near, facing, copy = <index into extractions> } ... ]`, from the table below. `facing` is the face's outward axis, `+x`, `-x`, `+z` or `-z` (and `+y`).
- `tools/models/parts.py`, after the assignment, before merging; pure helpers on plain lists, numpy free:
  - `hole_centre(point, facing, positions)`: the host part's vertices within 15 mm of the point across the face (distance measured in the face's plane); their height is the coordinate along `facing`; the deepest height and the vertices within 1 mm above it; the centre is their centroid across the face, at the height of the panel, the 80th percentile of the heights within 25 mm (the panel, robust to a bevel dropping away at a corner). Fails with a message naming the point when no vertex is near.
  - `cut_radius(centre, facing, positions)`: the vertices' mean height in 0.5 mm rings out to 15 mm; the radius of the lowest ring beyond 2 mm, the recess floor around the screw head.
  - An extraction moves every triangle of the host part (the brief part holding the nearest vertex, body or skirt) whose three vertices lie within the cut radius of the centre's axis into a new generated part `screw_<n>` assigned to `fittings`, removing them from the host.
  - An addition copies extraction `copy`'s triangles, turned by the quarter turns from its facing to the addition's (none when equal) about its centre, then moved from that centre to the addition's centre, into `addition_<n>` assigned to `fittings`.
  - Tests in `parts_test.py`: `test_hole_centre_finds_a_dimple_off_the_point` (a synthetic grid panel with a round 3 mm deep dimple 4 mm from the point), `test_cut_radius_finds_the_recess_floor` (a dimple with a raised head inside), `test_quarter_turn_between_facings`.
- `doc/workflows/models.md`, the finish step: the preprocess with `extractions` and `additions`.

| spot | near (metres, brief frame) | facing | kind |
|---|---|---|---|
| 1 | -0.4442, 0.0676, 0.5448 | +z | extraction |
| 2 | 0.4454, 0.0681, 0.5460 | +z | extraction |
| 3 | 0.2606, 0.2599, 0.5346 | +z | extraction |
| 4 | 0.4410, 0.8151, 0.2686 | +x | extraction |
| 5 | 0.4388, 0.8138, -0.2859 | +x | extraction |
| 6 | 0.4625, 0.4389, -0.2946 | +x | extraction |
| 7 | 0.4426, 0.2973, -0.4665 | -z | addition, copy of spot 9 |
| 8 | -0.4424, 0.2938, -0.4671 | -z | addition, copy of spot 10 |
| 9 | 0.4495, 0.0683, -0.4855 | -z | extraction |
| 10 | -0.4513, 0.0684, -0.4856 | -z | extraction |
| 11 | -0.4394, 0.8136, 0.2597 | -x | extraction |
| 12 | -0.4632, 0.4407, -0.2434 | -x | extraction |
| 13 | -0.4967, 0.2939, -0.4079 | -x | addition, copy of spot 14 |
| 14 | -0.5060, 0.2938, 0.4641 | -x | extraction |
| 15 | -0.5188, 0.0709, 0.4760 | -x | extraction |
