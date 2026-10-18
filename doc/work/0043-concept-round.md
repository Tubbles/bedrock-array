# 0043: The concept round

Status: designed (2026-10-18)

Goal: steps 3 and 4 of `doc/workflows/art_book.md`: a driver that composes a machine's prompt from its brief and its family's style paragraph, never by hand, and runs a round of repaints of the blockout's hero render through the image tool, and after the user's pick, the turnaround repaints with the chosen hero as the second reference. Refers to items 0040 and 0042.

Verify:
- `tools/art/concept.py smelter --round 1 --seeds 7 11 19` writes three images with their `prompt.txt` under `work/art/smelter/round-1/` (a real call, about fourteen cents an image on the OpenRouter key); the composed prompt is printed first and holds the family style, the silhouette, the feature and the repaint instruction.

## Specification (main agent, 2026-10-18)

Binding facts: `tools/art/generate.py` (its procedures: read the module's docstring and its `main`; it takes `--model`, `--prompt`, `--out`, `--seed`, `--reference` repeatable, and writes `<model>_<index>.<format>` beside `prompt.txt` with the model, the seed, the cost and the prompt); the brief keys (`data/machines/smelter/brief.sjson`: `silhouette`, `feature`, `family`, `art.model`, `figure_metres`); `data/art/families.sjson` (`<family>.style`); the blockout's renders under `work/art/<id>/blockout/` (`hero.png`, `front.png`, `left.png`, `back.png`, `right.png`).

- `tools/art/concept.py`, system Python (no Blender), puts `tools/materials` on `sys.path` for `sjson` and imports `generate`'s procedures rather than running it as a subprocess (add an `if __name__ == "__main__": main()` guard to `generate.py` if it has none). Commands:
  - `concept.py <id> --round <n> [--model <name>] [--seeds 7 11 19]`: the hero round. The prompt is composed as: the family's `style`, then "Repaint this blockout as finished concept art, keeping its silhouette, proportions, camera and the figure for scale exactly as they are." then the brief's `silhouette` and `feature` as two sentences, then "No text, no logos." The reference is `blockout/hero.png`. One call per seed with `--model` (default the brief's `art.model`) into `work/art/<id>/round-<n>/`, and the composed prompt printed before the first call.
  - `concept.py <id> --turnaround <hero image> --round <n>`: for each of `front`, `left`, `back`, `right`, one call with the view's blockout render as the first reference and the chosen hero as the second, the prompt composed as the family's `style`, then "The same machine as the second image, redrawn in the exact orthographic <view> view of the first image, keeping its silhouette and proportions; finished concept art, no text." into `work/art/<id>/round-<n>/turnaround/<view>.<format>`.
- Short procedures: the brief and family reading, the prompt composition (one procedure per prompt, returning the string), the round, the turnaround, `main` with argparse.
- No change to the workflow doc beyond the two command lines in its steps 3 and 4, if they differ from what is written there.

Verify: the hero round command above, read with the Read tool; the cost lines of the three `prompt.txt` files.
