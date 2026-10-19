# Plan

## End goal

The game of [definition.md](definition.md): a polished factory game on smooth voxel planets, Techtonica's quality and gamepad first, from the first dig on the surface to the caves below and the orbit above, moddable to the depth of Warcraft 3's world editor. The game is itself a set of wasm modules on the engine, so the modding API is proven by the game that ships on it.

## The way in

Three phases (user, 2026-10-18).

- **A. Tech demos.** A series of highly polished tech demos, each settling one thing (water behaviour, the art direction, the dig, the belts) and each defining one asset workflow by producing its first finished asset. The demos are small interactive web pages (user, 2026-10-18): Odin built to wasm for the browser with WebGL2 on a common engine package, one page per demo, served from bazzite so the user explores them on the phone and the laptop alike. No wasm host yet: polish and workflow are the point, and what they settle is engine grade code that moves into phase B rather than being rewritten.
- **B. The engine.** The wasm host, the natives, the modules and their intercom, the voxel store as a service, input, UI toolkit, saves, the editor, the modding documentation. No game level design and no world building until the engine stands.
- **C. The game.** Worldgen content, the factory, the spine of the first playable, then vehicles and orbit. Defined when phase B is in sight.

Beside the phases: the Techtonica study ([DESIGN.md](DESIGN.md), The Techtonica study), eight items that inform the demos, and the asset workflow research the definition's lesson 3 calls for, which each demo draws on.

## Phase A: the tech demos

Each demo answers one question. The user, on the phone and on the laptop, judges the answer on the page, and that judgement closes the demo. The web host on bazzite came before the first demo so both devices see every commit. The Steam shortcut and the couch build arrive with the native engine in phase B.

The user's reading on 2026-10-18, after D1's two pages: a renderer on flat coloured primitives decides nothing, so a demo's next item is always the one that moves its question, and engineering that can wait (the screenshot tool, clustered lights) waits. D1 runs on to its first finished material. After D1 the series below is pruned to the demos with a real open question (user, 2026-10-18), so the rows after D1 are provisional.

| Demo | The question | Defines the workflow for | State |
| --- | --- | --- | --- |
| D1 Light | Is stylised realism the look: worn paint with chipped edges over metal, a glowing face on a machine, a world lit by what glows, under a physically based light | Textures and materials | Parked as good enough (user, 2026-10-18), to be revisited as everything is. Settled: the renderer stages (0004 to 0027: shading, HDR and tone map, point lights, lens scattering bloom, hemisphere ambient, scene files, the cave and surface pages, touch, mouse, keyboard and gamepad input) and the material workflow with its first material, worn painted steel with chipped edges on the surface page's machine block (0028 to 0037, `doc/workflows/materials.md`, the fields as layer stacks). Not settled: shadows (stage 2), the sky model (D2), clustered lights and vertex ambient occlusion (the scenes that need them) |
| D2 Ground | Does the smooth voxel planet of Mine oh Belowed hold up under the new light, with sky, day and weather, and the powered pickaxe breaking terrain with debris and dust | Nothing new | Todo |
| D3 Water | Do cellular kernels with data rules give believable flow, pooling, a dug pit filling and draining, and a water surface | Nothing new | Todo |
| D4 Machine | Can one machine go from a brief to a finished model of the look's quality: concept, model, materials, animation, state cues as designed behaviours, alone and in a row of many | The art book and the modelling | Under way since 2026-10-18: the smelter first (user). Landed: the two workflows (0038, `doc/workflows/art_book.md` and `models.md`), the study's machine numbers (0039), the image tool (0040), the brief (0041), the blockout (0042, masks fixed in 0045), the concept driver (0043) and the review sheet (0044). Then the blockout's bevels, tapers and corner cuts (0048, 0049), the figure out of the renders (0050, 0051), the turnaround from each render alone (0052) and the collage round (0053 to 0055): the smelter's concept set, hero and four elevations, is kept under `data/art/smelter/` from one collage call on Nano Banana Pro (2026-10-19). Then the modelling's first step (0056, 0057): the four kept views to Tripo, the full model and three reductions, judged side by side on the models page (0058 to 0061). Next the finish step of the modelling workflow. Not a kit of primitives and not emissive levels as state, which would be Mine oh Belowed again (user) |
| D5 Belts | Do items travelling on belts between two machines, with lanes, splitting and merging, read as Techtonica's, drawn instanced | Nothing new | Todo |
| D6 Sound | Do cave ambience, the machine hum, belt and dig sounds hold up in no perceivable repetition clusters over the scene of D2 to D5 | Sound effects, and the Web Audio glue the pages need | Todo |
| D7 Screens | Do the inventory and crafting screen with the gamepad layers and glyphs in the 10 foot UI, Techtonica's bar, a gamepad through the browser's Gamepad API and touch as the pointer, work from the couch | Icons and UI art | Todo |
| D8 Music | Does a biome playlist with intensity layers carry the mood | Music | Todo |
| D9 Voice | Does a short Mission Control exchange, written and synthesised, pass lesson 1 | Writing and voice | Todo |

The Techtonica study ([DESIGN.md](DESIGN.md)) feeds D1 and D4 (study 6), D2 (4 and 5), D5 (1), D6 and D8 (7), D7 (3).

## Phase B: the engine

Written as items when phase A ends. The shape is [DESIGN.md](DESIGN.md), The engine and the modules: the wasm host carried from Heimdall, the natives and their versioning, the first module, the voxel store with the worldgen module's crossing, intercom with the factory module's skeleton and the crossing benchmark, the input layer and the actions module, the UI toolkit in the ui module, the materials module with the noise and voronoi natives (DESIGN.md, The material generator), saves, the editor, the modding documentation generated from the natives table, the native build on raylib with the couch path: the Steam shortcut, the play build install, the Deck delivery.

## Phase C: the game

Defined when phase B is in sight. The first target is the spine of [DESIGN.md](DESIGN.md), The underground: land on the surface under the sun, take the powered pickaxe, dig down, bring ore up from a cave lit by its flora, place the first machines above and below.

## Where it stands

- 2026-10-18: the definition read and worked out into DESIGN.md with the user (the engine and module split, intercom, cellular systems, the look and the renderer, the underground, asset storage, the Techtonica study, `doc/log/2026-10-18.md`). M0 landed the same day: the build script, the browser build with the hello page, the web host on bazzite at `http://192.168.1.7:8080/`, the draw list with the camera and the primitive meshes, Git LFS. D1 reached its two scene pages (the cave and the surface) the same evening, with the orbit, pan, walk and gamepad input the user asked for on the way. The user's reading of the pages: nothing decided yet, Mine oh Belowed with bloom. D1 ran on to its first finished material and the user parked it as good enough the same evening; the series after it is pruned next (the Phase A section, SUGGESTIONS.md).

## Milestones

| Milestone | Work items | Status |
| --- | --- | --- |
| M0 Structure | 0001 to 0005 | Landed 2026-10-18 |
| Phase A The tech demos | D1 parked as good enough 2026-10-18, D4 under way (the table above holds each demo's state) | Under way since 2026-10-18 |
| Phase B The engine | | Todo |
| Phase C The game | | Todo |
