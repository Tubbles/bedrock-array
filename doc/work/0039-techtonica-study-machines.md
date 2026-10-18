# 0039: Techtonica study, the machines

Status: verified (2026-10-18)

Goal: question 2 of the Techtonica study (DESIGN.md, The Techtonica study): the grid cell size, the footprints and blocked areas per machine, the placement and snapping rules, the rotation, read from the local install with the study's tools (AssetRipper over the Addressables for the machine definitions and prefabs, ILSpy over `Assembly-CSharp.dll` for the placement code), so the smelter's brief of D4 carries measured sizes rather than guesses. The boundary of the study holds: mechanisms and numbers only, nothing of Techtonica's enters the game. Refers to item 0038.

Verify:
- `doc/techtonica.md` (new, the study's findings document) holds the cell size, a table of machine footprints and heights with the asset each number came from, the placement and rotation rules with the class they came from, and the smelter's numbers; the exports stay under `work/techtonica/`, uncommitted.

Route, 2026-10-18: UnityPy with its type tree generator over the game's managed assemblies reached the machine definitions in `sharedassets1.assets`, not the Addressables; AssetRipper was not needed. Installed for the study: dotnet and uv from Homebrew, ilspycmd as a dotnet tool, UnityPy in a venv under `work/techtonica/`.
