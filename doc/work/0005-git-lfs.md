# 0005: Git LFS for binary assets

Status: todo (2026-10-18)

Goal: git-lfs installed through Homebrew, `git lfs install` run, `.gitattributes` routing images, audio, models and fonts to LFS as DESIGN.md's Asset storage lists them, and `doc/build.md` naming the quota rule (CI caches its objects, the Deck gets copies).

Verify:
- `git lfs ls-files` lists a committed test image, and `git show HEAD:<image>` prints a pointer.
