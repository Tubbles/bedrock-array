# 0077: The play build and the Steam shortcut

Status: landed (2026-10-19, 3105195)

Goal: the binary reaches the TV through Steam the way Mine oh Belowed's does (user, 2026-10-19): a release build installed under `bin/play/builds/<stamp>-<commit>/`, a `current` link switched by one rename so an install while the game runs only moves the link and the next launch takes the newest, the two newest builds kept and a running one never removed, a launcher `bin/bedrock-array` the Steam shortcut points at, and `tools/add_steam_shortcut.py` writing that shortcut into Steam's `shortcuts.vdf` from the command line.

Verify:
- `tools/install_play_build.sh` installs HEAD: `bin/play/current` resolves to the new build, `bin/bedrock-array` runs it (`bin/bedrock-array --frames 3` under `xvfb-run` exits 0), a second install keeps two builds and removes a third.
- `tools/add_steam_shortcut.py --dry-run` prints the shortcut it would write.

## Specification

- `tools/install_play_build.sh`: Mine oh Belowed's (`~/dev/mine-oh-belowed/tools/install_play_build.sh`) with the names changed: `bedrock-array`, `BEDROCK_ARRAY_COMMIT`, `BEDROCK_ARRAY_X11`, `BEDROCK_ARRAY_GAMESCOPE`, the build through `build.sh release` from a git archive, no `data/` beside the binary and no data variable, since the app embeds its scenes, meshes and textures with `#load` (an item that reads data at run time adds them back), the `--target user@host:path` path kept for the Deck (`.gitignore` already ignores all of `/bin/`).
- `build.sh` already takes `BEDROCK_ARRAY_COMMIT` from the environment for the stamp (`build_commit`), and a `git archive` of this repository carries the LFS mesh content (checked 2026-10-19), so the archive build needs nothing more.
- `tools/add_steam_shortcut.py`: Mine oh Belowed's (`~/dev/mine-oh-belowed/tools/add_steam_shortcut.py`) with `APP_NAME = "Bedrock Array"` and the executable `bin/bedrock-array`, the docstring kept (Steam closed while it runs, the file round trips byte for byte or nothing is written).
- `doc/build.md`: a "Play build" section and a "Steam shortcut" section in the words of Mine oh Belowed's `doc/build.md` (lines 165 to 172 there) with the names changed; `CLAUDE.md`'s stack line: after every commit on `main` the play build is installed too and the reply names it.
