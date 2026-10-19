# 0104: Close and decimate per part

Status: landed (2026-10-19, dd947e2)

Goal: the finish step's second part: each brief part of the generated model is closed by Poisson at a fixed cell size and decimated to its share of a level's triangle budget, so the gaps between parts stay open and every part keeps its material (user, 2026-10-19: "lets go"). Follows 0102.

Verify:
- `python3 -m unittest discover -s tools/models -p "*_test.py"`; `tools/models/finish_parts.sh smelter 192000` writes one blob per brief part with its triangles summing to within a few percent of 192000, every blob in the brief's frame (the same bounds as the part's blob from 0102 to within a cell or two).

## Specification

- `tools/models/parts.py`: `--ply-directory <dir>` also writes each brief part's merged mesh as `<dir>/<brief part>.ply` (binary little endian PLY, vertex x y z nx ny nz as float, face as a uchar count and int indices) through a new `write_ply(path, vertices, indices)`. Test `test_write_ply_round_trips_the_header_and_counts` in `parts_test.py`.
- `tools/models/reconstruct.py`: `--cell <metres>` (Poisson only, exclusive with `--depth`) picks the depth as `ceil(log2(1.1 * largest bounding box extent / cell))` clamped to 4..10 and prints it. It loads a PLY as it loads a GLB already (pymeshlab reads both).
- `tools/models/mesh_blob.py`: `--keep-frame` writes the positions as they are, without the grounding, for meshes already in the brief's frame.
- New `tools/models/finish_parts.sh <machine> <total> [<total> ...]`: runs `parts.py <machine> --ply-directory work/models/<machine>/parts/`, closes each part with `reconstruct.py --technique poisson --cell 0.0025` into `<part>_poisson.ply`, reads each closed face count from the PLY header, gives each part `max(24, round(total * part / sum))` triangles of each total, runs `decimate.py` (under the Blender flatpak with `$PWD` absolute paths, as `close_all.sh` does) to `<part>_poisson_<total>.glb` and `mesh_blob.py --keep-frame` to `data/demos/parts/meshes/<part>_<total>.mesh`, skips a step whose output exists like `close_all.sh`, and prints each part's depth, closed count and budget.
- `doc/workflows/models.md`, the finish step: the per part closing and decimation with the tool.
