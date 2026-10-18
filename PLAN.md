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

A proposal, open to the user (SUGGESTIONS.md). Each demo is a milestone with one verify statement: the user, on the phone and on the laptop, judges it as release quality. Both see every commit from the first page on, so the web host on bazzite comes before the first demo. The Steam shortcut and the couch build arrive with the native engine in phase B.

| Demo | Settles | Defines the workflow for | Draws on |
| --- | --- | --- | --- |
| D1 Light | Renderer stage 1 (physically based forward shading, clustered lights, HDR, bloom, vertex ambient occlusion), the material library, stylised realism in the concrete: a cave lit by its flora and a surface under the sun, primitives in library materials | Textures and materials (parametric generation, generated physically based sets) | Techtonica study 6 |
| D2 Ground | The smooth voxel planet carried from Mine oh Belowed under the new light, sky, day and weather, the powered pickaxe breaking terrain with debris and dust | Nothing new, the first dig sounds wait for D6 | Study 4 and 5 |
| D3 Water | The cellular kernels with data rules: flow, pooling, a dug pit filling and draining, the water surface | Nothing new | |
| D4 Machine | One machine from the art book to a finished model: concept, model, materials, animation, state cues (glow, motion, heat), alone and in a row of many | The art book and the modelling (Blender) | Study 2 and 6 |
| D5 Belts | Items travelling on belts between two machines, lanes, splitting and merging, instanced drawing | Nothing new | Study 1 |
| D6 Sound | Cave ambience, the machine hum, belt and dig sounds, in no perceivable repetition clusters, over the scene of D2 to D5 | Sound effects, and the Web Audio glue the pages need | Study 7 |
| D7 Screens | The inventory and crafting screen with the gamepad layers and glyphs in the 10 foot UI, Techtonica's bar, a gamepad through the browser's Gamepad API and touch as the pointer | Icons and UI art | Study 3 |
| D8 Music | A biome playlist with intensity layers | Music | Study 7 |
| D9 Voice | A short Mission Control exchange, written and synthesised, that passes lesson 1 | Writing and voice | |

## Phase B: the engine

Written as items when phase A ends. The shape is [DESIGN.md](DESIGN.md), The engine and the modules: the wasm host carried from Heimdall, the natives and their versioning, the first module, the voxel store with the worldgen module's crossing, intercom with the factory module's skeleton and the crossing benchmark, the input layer and the actions module, the UI toolkit in the ui module, saves, the editor, the modding documentation generated from the natives table, the native build on raylib with the couch path: the Steam shortcut, the play build install, the Deck delivery.

## Phase C: the game

Defined when phase B is in sight. The first target is the spine of [DESIGN.md](DESIGN.md), The underground: land on the surface under the sun, take the powered pickaxe, dig down, bring ore up from a cave lit by its flora, place the first machines above and below.

## Where it stands

- 2026-10-18: the definition read and worked out into DESIGN.md with the user (the engine and module split, intercom, cellular systems, the look and the renderer, the underground, asset storage, the Techtonica study, `doc/log/2026-10-18.md`). M0 landed the same day: the build script, the browser build with the hello page, the web host on bazzite at `http://192.168.1.7:8080/`, the draw list with the camera and the primitive meshes, Git LFS. D1 is under way with items 0006 to 0008.

## Milestones

| Milestone | Work items | Status |
| --- | --- | --- |
| M0 Structure | 0001 to 0005 | Landed 2026-10-18 |
| D1 Light | 0004, 0006 to 0008, then the shading, light and sky items | Under way since 2026-10-18 |
| D2 Ground | | Todo |
| D3 Water | | Todo |
| D4 Machine | | Todo |
| D5 Belts | | Todo |
| D6 Sound | | Todo |
| D7 Screens | | Todo |
| D8 Music | | Todo |
| D9 Voice | | Todo |
| Phase B The engine | | Todo |
| Phase C The game | | Todo |
