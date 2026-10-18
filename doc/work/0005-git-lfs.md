# 0005: Git LFS for binary assets

Status: verified (2026-10-18)

Goal: git-lfs installed through Homebrew, `git lfs install` run, `.gitattributes` routing images, audio, models and fonts to LFS as DESIGN.md's Asset storage lists them, and `doc/build.md` naming the quota rule (CI caches its objects, the Deck gets copies).

Verify:
- `git check-attr -a -- data/example.png` prints `filter: lfs`, `diff: lfs` and `merge: lfs`, the same for a `.wav`, a `.glb` and a `.ttf` path, and `git check-attr -a -- data/example.sjson` prints nothing.
- `git lfs env` names the GitHub endpoint for this repository.

## Specification (main agent, 2026-10-18)

git-lfs comes from Homebrew (the main agent installs it before this item starts, `git lfs version` must print a version) and `git lfs install` has been run once by the main agent, which adds the smudge and clean filters to the user's git configuration. The implementer touches only the repository.

- `.gitattributes` (new): one line per extension, `*.<ext> filter=lfs diff=lfs merge=lfs -text`, for images (`png`, `jpg`, `jpeg`, `exr`, `hdr`), audio (`wav`, `ogg`, `flac`, `mp3`), models (`glb`, `gltf`, `fbx`, `vox`, `blend`) and fonts (`ttf`, `otf`), grouped under one comment line each. Text formats (`sjson`, `glsl`, `obj`, `mtl`) are not listed, so they stay plain. The upper case variants (`PNG`, `JPG`) are listed too, since generators save them.
- `doc/build.md`: a section `## Large files` stating the rule of DESIGN.md's Asset storage in two or three lines: binaries under the listed extensions are Git LFS objects on GitHub, text stays plain; a fresh clone needs `git lfs install` once per machine (Homebrew's git-lfs here) and then fetches the objects on checkout; the bandwidth rule (CI caches its LFS objects between runs, the Deck receives copies of the built tree, never a clone); and that `.gitattributes` is the one place the routing lives.

Verify: as above, plus `./build.sh check` and `./build.sh test` still pass (nothing in them changes).

