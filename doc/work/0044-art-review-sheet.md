# 0044: The art review sheet

Status: designed (2026-10-18)

Goal: step 5 of `doc/workflows/art_book.md`: one sheet per round that puts the blockout renders, the repaints, the turnaround and a squint row side by side, with the checks printed, so a round is judged in a minute. Refers to items 0042 and 0043.

Verify:
- `tools/art/sheet.py smelter --round 1` writes `work/art/smelter/round-1/review.png` and prints one line per check; a round without a turnaround still gets its sheet.

## Specification (main agent, 2026-10-18)

Binding facts: the blockout renders and masks under `work/art/<id>/blockout/` (`hero.png`, `front.png`, `left.png`, `back.png`, `right.png`, each with a `<view>_mask.png`, white on black, machine only, 1024 square); the round's images under `work/art/<id>/round-<n>/` (`<model>_<index>.<format>`) and its turnaround under `round-<n>/turnaround/<view>.<format>`; `data/art/families.sjson` and the brief's `family` key; Pillow is in the system Python (`generate.py` uses it), numpy is not.

- `data/art/families.sjson`: each family gets `palette`, a list of sRGB colours in 0..1, the furnace's: paint `[0.2, 0.24, 0.3]`, copper `[0.95, 0.64, 0.54]`, bare metal `[0.56, 0.57, 0.58]`, glow `[1.0, 0.55, 0.2]`.
- `tools/art/sheet.py`, system Python, Pillow only, `tools/materials` on `sys.path` for `sjson`. Command `sheet.py <id> --round <n>`. Rows of 256 pixel cells with a label under each, left to right: row 1 the blockout hero and the four views; row 2 the round's repaints sorted by name; row 3 the turnaround views that exist; row 4 every image of rows 2 and 3 as a 64 pixel greyscale thumbnail scaled up four times with nearest sampling (the squint row). A horizontal line at the hero mask's top row across rows 1 and 2 (the height line). Output `work/art/<id>/round-<n>/review.png`.
- The checks, one printed line each, `<CHECK> <image> <value> ok|warn`: `SILHOUETTE`, the overlap (intersection over union) of a repaint's foreground with its blockout mask, counted inside the mask's bounding box grown by 5 percent of the image side so the figure beside the machine stays out; the foreground is the pixels farther than 0.15 (Euclidean, sRGB 0..1) from the background colour, the median of the image's border pixels; ok above 0.85. Hero repaints against `hero_mask.png`, turnaround views against their view's mask. `PALETTE`, the share of a repaint's pixels inside its mask within 0.25 of a palette colour; ok above 0.6. `HEIGHT`, the foreground's bounding box height over the mask's; ok within 0.05 of 1.
- Short procedures: the reading of the round's files, the foreground mask, each check as a pure procedure returning its value, the cell placement, `main` with argparse. Starting values, tuned on the first round's sheet.
- `doc/workflows/art_book.md` step 5 rewritten to the command, the output path and the three checks as implemented, no longer than it is.
