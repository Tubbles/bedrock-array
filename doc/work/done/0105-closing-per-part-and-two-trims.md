# 0105: The closing per part and two trims

Status: landed (2026-10-20, a0b1916)

Goal: the closed smelter without the copper lips that 0104's 1 cm trim left on the steel around the fittings: small parts skip Poisson, and a 3 mm trim is compared with the 1 cm one in the parts demo (user, 2026-10-20: "we definitely should do 2", "We could try 1 but maybe make that toggleable in the demo"). Follows 0104.

Verify:
- `python3 -m unittest discover -s tools/models -p "*_test.py"`; both runs of `finish_parts.sh` write their blobs; the lip measure (the share of closed vertices more than 6 mm from the raw part, `tmp/parts/lip_check.py`) drops for the 3 mm trim and is near zero for the skipped parts; `./build.sh web parts` and `./build.sh smoke`.

## Specification

- `data/machines/smelter/generated.sjson`: `closing = { fittings = "none", vents = "none", louvre = "none" }`, a brief part to `"poisson"` (the default for a part not listed) or `"none"` (decimation only).
- `tools/models/parts.py`: `--closings` prints one `<brief part> <closing>` line per brief part with a blob and exits; an unknown closing value is an error. Test `test_closing_defaults_to_poisson`.
- `tools/models/finish_parts.sh <machine> --trim <metres> <total> [<total> ...]`: the trim becomes an argument; a part closed `none` is decimated from its raw `<part>.ply`; the outputs carry the trim in millimetres, `work/models/<machine>/parts/<part>_poisson_trim<mm>.ply` and `data/demos/parts/meshes/<part>_<total>_trim<mm>.mesh` (a `none` part's blob carries it too, so each run is complete on its own). The 0104 blobs `<part>_192000.mesh` are removed (git rm) once the 10 mm run has replaced them.
- Runs: `--trim 0.01 192000` and `--trim 0.003 192000`.
- `data/demos/parts/scene.sjson`: configurations `["as generated", "closed, 1 cm trim", "closed, 3 mm trim"]`, each item's `files` in that order; the scene comment and `src/demos/parts/description.txt` say what the three are.
- `doc/workflows/models.md`: the closing per part and the trim argument.
