# 0041: The smelter's brief

Status: verified (2026-10-18)

Goal: step 1 of `doc/workflows/art_book.md` for the first machine: `data/machines/smelter/brief.sjson` with the keys the workflow names plus a `blockout` per part (shape, size, position) for the blockout script, and the `furnace_glow` preset in the material library for the window. The sizes are provisional until the Techtonica study (item 0039) lands; the brief says so in its comment. Refers to items 0038 and 0039.

Verify:
- The brief parses with the tools' reader (six parts, three cues); `./build.sh test` passes with the new preset.
