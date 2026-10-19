# 0055: The collage on the review sheet

Status: landed (2026-10-19, 38548b4)

Goal: the review sheet does not know the collage round, so its panels were scored by hand, and a rerun of a round overwrites the panel files while the sheet output is numbered (the two open points of item 0053). The panels carry their output's number and the sheet shows and checks every collage of a round.

Verify:
- After `mv` of the five panels of `work/art/smelter/round-10/collage/` from `<name>.png` to `<name>_0.png`: `python3 tools/art/sheet.py smelter --round 10` prints fifteen check lines named `collage/hero_0.png` through `collage/right_0.png` (silhouette hero 0.79, front 1.00, left 0.91, back 0.87, right 0.97), writes `review.png` with three rows, the blockout, the collage and the squint row, the height line across the blockout row only.
- `python3 tools/art/sheet.py smelter --round 7` prints and lays out as before: blockout, repaints, turnaround, squint, the line across the first two rows.
- `python3 tools/art/concept.py smelter --collage --round 11 --dry-run` prints as before.

## Specification

- `tools/art/concept.py`: `write_panels(out, image_data, index)` names the panels `<name>_<index>.png`; `collage_round` takes the index from the written output's stem (`banana_3` gives `3`, the part after the last underscore of `written[0]`'s stem), so a rerun of a round adds a set beside the earlier one as `generate.write_images` numbers its outputs. The seed suffix goes. The module docstring's sentence names `<view>_<index>.png`.
- `tools/art/sheet.py`: `collage_sets(round_directory)` returns `[(index, panels)]` for each output `collage/<model>_<index>.png` found by `images_in` whose stem's head (before the last underscore) is not a panel name and not `sheet`, with `panels` the `(name, path)` pairs of `["hero"] + VIEWS` whose `collage/<name>_<index>.png` exists, in that order. `main` prints each panel's `check_lines` named `collage/<file>` against `<name>_mask.png`, adds one row per set after the turnaround row with the panels labelled by file stem, puts the panels into the squint row after the turnaround views, drops empty rows, and draws the height line across the blockout row and the repaints row when the round has repaints: `build_sheet(rows, line_rows, mask_top, mask_side)` with `line_rows` the indices to draw on. The module docstring's Rows sentence gains the collage rows.
- `doc/workflows/art_book.md`: step 3's collage sentence names the panels `<name>_<index>.png`; step 5's row list gains the collage rows.
