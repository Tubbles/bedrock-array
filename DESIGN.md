# Bedrock Array design

Companion to [definition.md](definition.md). The definition states intent, this document works the intent out into decisions, the reasons behind them and the questions still open. It follows the definition as it changes: each section names the passage it works out.

Sources this document builds on, read 2026-10-18: the heimdall repository (`github.com/Tubbles/heimdall`, the wasm host), and in Mine oh Belowed the engine and game cut brief `doc/work/0146-engine-and-game-logic-cut.md`, the "Engine or game" sections of `doc/audit/world.md`, `doc/audit/simulation.md` and `doc/audit/ui.md`, and `doc/input.md`. They are cited, not restated.

What transfers from Mine oh Belowed is technique and systems: the engine side, the input layer, the renderer's methods, the planets. Its content, narrative and art direction do not (user, 2026-10-18, confirming this reading of the definition's copy and drop lists).

## The engine and the modules

Works out: "This project's core game shall also be implemented in multiple wasm modules" and the Warcraft 3 paragraph of the definition.

### The rule

The engine, native Odin with raylib, owns work that scales with voxels, pixels, audio samples or file bytes, and everything that talks to the window, the GPU, the audio device, an input device or the file system. A module, Odin compiled to wasm and run on wasmtime, owns work that scales with game entities, rules and content.

A module is not slow in itself: wasmtime compiles it to native code at load (Heimdall's `plugin.compile` calls `module_new`, which runs wasmtime's default compiler, Cranelift). What costs is the crossing. A host call pays for argument marshalling and a bounds checked view of guest memory, and the simulation audit's one heavy caller in Mine oh Belowed was the player's collision sweep reading blocks many times per tick. So the cut falls where crossings are few and carry lists, not where the arithmetic is heavy. "Accelerated" in the definition's sense means moved to the side that avoids a crossing per voxel, per pixel or per sample.

### The engine side

| Area | Owns | Why the engine |
| --- | --- | --- |
| Frame and tick | The window, the frame loop, the fixed tick clock, the order in which modules run, pause | One owner of time, or determinism is gone |
| Renderer | Voxel meshes, models, particles, sky, lights, post effects, text, all from lists the modules hand over | Per pixel, GPU |
| Voxel store | Chunks of block ids, the block registry the modules fill at load (shape, light, opacity, collision, texture tiles), light, meshing, the raycast, streaming with worker threads, the chunk codec, the cell occupant index | Per voxel, shared by every module, Mine oh Belowed's world audit section 6 lists the pieces |
| Collision | The sweep of a box through blocks and occupied cells | Many block reads per step, the one host caller the simulation audit found too heavy |
| Audio | Mixing, playback, streaming, positioning, the "no perceivable repetition" clusters for sounds and cadences | Per sample, and a quality the engine makes its own |
| Input devices | SDL3 for gamepads (Steam Controller paddles, trackpads, gyro, touch sense), raylib for keyboard and mouse, the device snapshot per frame, controller glyph tables | Devices, carried from Mine oh Belowed's two backends (`doc/input.md`) |
| Assets | Loading, decoding and GPU upload of models, textures, sounds, fonts and shaders, by id, with a file watcher for hot reload | File bytes, GPU, OS |
| Files | Reading and atomic writing under virtual roots (data, saves, mods, config), listing, watching | The wasm sandbox has no file system |
| Wasm host | The wasmtime engine, one store per module instance, one linker shared by all modules, the natives table, load, reload and trap handling, serialized compiled modules as a load time cache | It is the host |
| Determinism | Queued inputs applied at the start of a tick, so a module is a function of its inputs, with tick replay | Replay, lockstep and a server fall out of it (0146) |

### The module side

The definition names world generation, machines and vehicles. The set the core game is proposed to split into, each replaceable by a mod:

| Module | Owns |
| --- | --- |
| worldgen | Biomes, veins, flora and fauna placement, spawn rules, the chunk fill. One instance per worker thread, since a wasmtime store is single threaded. In: seed and chunk coordinate. Out: the block ids of the chunk and the game's own records (world audit section 6 sized the crossing against the generation time and found it small) |
| factory | Machine kinds and their ticks, belts and the items on them, inventories including the player's, power and fluid networks, placement rules, recipes. One module because items move between all of these every tick |
| vehicles | Rockets, orbit travel, the strapped in seat view with free look |
| player | Movement intent, digging and placing as block writes, interaction with the factory by events and calls |
| actions | The device snapshot mapped to actions through the bindings file, the rebind screen, the Steam Controller's extra buttons as quality of life shortcuts |
| ui | The HUD, screens, dial rings and glyph bar, with the UI toolkit compiled in and a UI draw list out |
| editor | The in game editing of SJSON data, the string builder and trigger designer the definition points at sleipner for |

Entities live in guest memory. The engine never iterates them, it reads views (pointer and length into guest memory) of the per frame draw list, the camera, the sounds and the UI draw list. A host side entity store would put every component read of a 60 Hz tick behind a host call. This is 0146's object model and it stands here unchanged: kinds as compile time archetypes, component structs embedded in kind structs, systems over component views, generational handles carrying the kind, pool order as iteration order.

The grouping rule: a data flow that runs per entity per tick never crosses a module border. Whether actions and ui merge is decided by the first vertical slice, not now.

Module code compiles both ways (user, 2026-10-18): a module is a plain Odin package, built to wasm for the shipped game and natively for its tests and for a fused debug build with the modules linked in. The couch build always runs the wasm build, so the natives stay dog-fooded.

### The natives

The natives are the host functions every module may import, the Warcraft 3 sense of the word. Grouped:

- Voxels: read blocks as a query list or as a copy of the chunks around a box into guest memory, write blocks as a list the engine applies at the end of the tick, raycast, sweep, register block kinds at load, and per tick the chunk arrival and unload lists.
- Frame outputs, module to engine: the camera, the draw list (model id, transform, animation phase, tint, light cell), particle spawns, lights, sounds to play, the UI draw list. Handed over as views, read in place.
- Input, engine to module: the device snapshot written into guest memory each frame. Key states, mouse delta, every gamepad's axes and buttons including paddles, trackpads and gyro, touch. Accumulating frames into a tick is the module's business, as `Tick_Input_Accumulator` does in Mine oh Belowed.
- Assets: name to id at load, text measurement for the UI (glyph metrics copied into guest memory once per font, so no call per string).
- Files: read, write, list and watch under the virtual roots.
- Time and log: tick number, frame delta, a log line.

Rules for the crossing:

1. No host call per entity per tick. What a tick needs per entity lives in guest memory or arrives in one call carrying a list.
2. Outputs are views. The engine reads guest memory in place and copies only what must outlive the frame.
3. Strings cross at load and in the editor, never per frame.
4. A struct that crosses has the same layout on both sides and holds no pointers: wasm32 pointers are 32 bit offsets, native ones are 64 bit. Indices and offsets instead. Heimdall crosses raylib's `Vector2` and `Color` this way, value types without pointers.
5. The surface is versioned, and a module declares the version it was built against.
6. The cost per crossing is measured with a factory benchmark before the surface is frozen (0146 asks for the same).

### Two layers, as in Warcraft 3

Warcraft 3 had the natives (the engine) and `Blizzard.j`, a library written in JASS on top of them that the melee game and most maps used. Here the natives are the engine's host functions, and the core modules' exports are the library: the machines module exports what a machine kind must provide, the ui module exports its widgets, the actions module exports its action ids.

A mod that designs a new game system uses the natives directly and ignores the core modules. A mod that adds a machine talks to the machines module. The natives surface stays small and stable, the module exports evolve with the modules. This is why the core game must itself be modules: the library only exists if the game is written against it.

### Intercom

Decided 2026-10-18. Modules reach each other only through the engine, with two primitives.

- Events. Each module keeps an outbox in its own memory. The engine runs the modules in a declared order every tick and copies outbox entries into the subscribers' inboxes at each module boundary. A downstream module sees this tick's events, an upstream one sees them next tick. The order is fixed, so replay holds.
- Calls. One native: call module X's function F with this request. The engine copies the request into the callee's memory, runs the exported entry and copies the response back. For a panel reading one machine's slots each frame, a few hundred bytes per frame.
- Both carry the pointer free, fixed layout structs of the natives rules.

The consequence is the grouping rule above: a per entity per tick flow never crosses a border, so the factory is one module, and a new machine kind comes from data (a prototype listing its components, as 0146 sketches), not from code in another module. A mod that needs new per tick code owns those entities in its own module and uses the natives.

Rejected: direct imports through the linker (both instances must share one wasmtime store, and a pointer argument means nothing in the other module's memory, so only scalar calls would work); one memory imported by every module (each separately linked Odin module places its data segment, stack and heap at its own addresses, and nothing in Odin's build flags links wasm modules together, so the partition would be by hand); the component model (no Odin tooling).

### The material generator

Decided 2026-10-18 (the user's thought, the main agent's sketch). A material's procedural fields are layer stacks in SJSON (`doc/workflows/materials.md`, The fields), and the generator that evaluates them is a `materials` module: it exports `generate(stack, size)`, fills the map in its own memory and hands the engine one pixel view per map, which the engine uploads as it reads a draw list. One crossing per map, no call per texel, so the rule holds. The engine offers the heavy primitives as natives, fill this buffer with 4D noise or voronoi at a scale and seed, threaded and vectorised, a handful of crossings per map; a module may compute its own primitives in guest memory, slower but allowed, which is how a mod adds a kind the engine never heard of. The module's exports are the vocabulary the editor edits: the kinds, the combines and their keys. A mod that wants a new kind, another curve or a new combination ships its own module with the same entry and ignores the core one, the two layer rule. Two data extensions come before any code: a named curve for `gate` and `mix` (smoothstep, linear, smootherstep, a list of points) and expression layers (a layer that is a `mul` or `add` of sub stacks).

The module is a pure function of stack and seed, so it hot reloads without state: edit, build to wasm, the file watcher reloads it, every stack in use is generated again and uploaded. A procedural material then ships as a stack and a seed, regenerated at load, deterministic, no texture files. Blender's noise is not Odin's: the stack is the contract and the noise functions an implementation, so the look shifts and is retuned on the review sheet when the generator moves, and Blender keeps the review render. The engine's noise kernel in Odin, pure and tested, is the optional phase A step that makes the shift smaller.

### Cellular systems

Decided 2026-10-18. Water, decay and growth are engine kernels, their rules are block data.

- They are per voxel neighbourhood work over data the engine already holds for meshing and saving, so the rule puts them in the engine.
- The rules live in the block registry a module fills at load. A fluid block declares spread distance, flow rate, whether it falls and a source flag. A decaying block declares its delay, its replacement and the neighbour that keeps it alive. A spreading block declares what it grows onto and how fast. Three parameterised kernels cover Mine oh Belowed's water and leaf decay, and a mod adds a fluid or a moss from data alone.
- The scheduled cell queue saves with the chunks, the only place a save can resume mid flow from.
- Entities interact through the occupant index flags as 0146 has it: a turbine passes water, a wall blocks it.
- The escape hatch, built the first time a mod needs it: a block kind marked module ticked. The engine still schedules it and hands the module one list per tick of due cells with their 27 cell neighbourhoods, taking back a write list. One crossing per tick, not per cell.

### Open

- Worldgen's column queries outside the workers (terrain height, biome at a point, veins near a box, used by the map, the survey and ambient life): a worldgen instance on the main thread as well, or the engine keeping the column data per loaded chunk.
- Player movement: the sweep is engine, the integration of velocity against the sweep's result is module. Whether that is one crossing per step or too many is a measurement.
- Saves: 0146 recommends the module serializes its own state through a by name schema codec compiled into it (a raw memory snapshot would not survive a rebuilt module), the engine owns the files and the blocks. Adopted unless the first save format shows otherwise.

## The look and the renderer

Works out: "Realistic rather than cartoonish", "From techtonica: High quality and polish", lesson 1 (placeholder art) and lesson 3 (asset workflows) of the definition. Mine oh Belowed's art direction (astro-industrial punk, `DESIGN.md` Art direction) is on the definition's drop list and is not carried. Its genre look research (`doc/inspiration.md`, How machines look in the genre) and its renderer are read for what transfers.

### The target: stylised realism

Decided 2026-10-18. "Realistic" is read as real light on real materials, and "not cartoonish" as no outlines, no flat shading, no toy palette. The shapes stay simplified. That is Techtonica's recipe as the inspiration notes describe it: squat machines with one big readable feature each, worn paint with chipped edges over metal, a glowing window as the face of a furnace, small screens and holograms, a world lit by what glows in it.

- Realistic: physically based materials (albedo, metal, roughness, normal, emissive), a physically based sun and sky, HDR with exposure, bloom only from emissives, shadows, darkness in cavities.
- Stylised: silhouettes of a few large shapes, low texture detail (no photographic grime), one material palette per machine family, saturated emissives as the state cue.

Why not photoreal: lesson 1 and lesson 3 together. A generated asset pipeline reaches clean shapes with a plausible material more reliably than photographic detail, in my reading of the current generators and to be confirmed by the asset workflow research the definition calls for. Under a photoreal target every imperfect asset reads as broken. Under stylised realism a plain shape under good light reads as unfinished, which is survivable.

### Consistency comes from the renderer

Assets will come from different generators, runs and vendors. What makes them one world is what they share: the lighting, a material library, a palette per family, and the grading pass. So a model carries geometry, UVs, a material id per part and masks (wear, emissive), never its own baked look. The material library is a fixed set of presets (painted steel, bare alloy, copper, glass, rubber, concrete and so on), each with its physically based parameters and a wear rule, and it is data the editor can tune. Textures are generated from parameters where they can be, as Mine oh Belowed's field materials are (`doc/presentation.md`, The field shader), and the no perceivable repetition principle holds: isotropic, triplanar, read at two scales so the period never shows.

The same library is what makes a mod's machine look native: built from the presets, it is lit and graded like the core's.

### Placeholders

Lesson 1 as a rule: nothing improvised goes into the build. A placeholder model is a primitive (box, drum, cylinder) of the final size, with a material from the library, lit by the real renderer. It reads as not yet built, not as badly built. A placeholder text is absent, not a quip: a message not yet written is not shown. Mission Control's voice is an asset workflow of its own.

Hence the order: the renderer and the material library come before the first real asset, and the first playable is grey shapes under the final light.

### Renderer scope

What raylib 6 gives, read from Mine oh Belowed's vendored bindings (`shared/raylib/raylib.odin`, `rlgl/rlgl.odin`): the window and an OpenGL 3.3 context by default, meshes and models with material map slots for the physically based set (albedo, normal, metalness, roughness, emission, occlusion, cubemap, irradiance, prefilter, BRDF), custom shaders with uniform and texture access, render textures, cubemaps, mipmaps, instanced mesh drawing, model animation with blending, and through rlgl raw framebuffers and compute shader dispatch when raylib is built for OpenGL 4.3. What it does not give: shadow mapping, light management, an HDR pipeline, a post stack, deferred or clustered shading. Those are engine work in GLSL over rlgl, which is how Mine oh Belowed already drew everything (`data/shaders/`: chunk, field, model, water, flame, arrival).

What transfers from Mine oh Belowed's renderer, technique not design: the sky, day and weather system with fog, the generated triplanar materials at two scales, per vertex voxel light (sky light and coloured block light), the nearest point lights as uniforms, fire as a flow, culled greedy meshed chunks, the smooth planet field meshes. What it lacks for the target: physically based shading, shadows, HDR with tonemapping and bloom, ambient occlusion, normal maps, instancing (its belts are drawn one by one), and more than a handful of lights.

The build, staged by milestone:

1. For the first playable: physically based forward shading with the sun and sky ambient from the sky model, clustered lights (the early game is a bootstrap factory underground, lit by its lamps and the glowing flora, see The underground), an HDR target with exposure and tonemapping, bloom from emissives, vertex ambient occlusion on the voxels, instanced belt items and machine parts.
2. Then: cascaded shadow maps for the sun, screen space ambient occlusion.
3. Then: atmospheric scattering for the surface to orbit transition, volumetric fog underground, the water surface.

Every stage sits behind a setting where it costs, budgeted for the Steam Deck at 1280 by 800, Mine oh Belowed's technical rule carried over, and during phase A for the phone the demos run on.

The tech demos are browser pages (user, 2026-10-18, PLAN.md The way in), so the renderer is first written against WebGL2, OpenGL ES 3.0 class: no compute shaders, HDR through float render targets, several render targets per pass. Stage 1's light clustering therefore runs on the CPU each frame into a light index texture or uniform block the fragment shader reads, which also serves the phone. The shaders are GLSL ES 3.00 and carry to the native renderer under a version preamble. Building raylib for OpenGL 4.3 and moving the clustering into compute is an optional native upgrade measured in phase B, not a stage 1 need.

Because the modules hand the engine draw lists and never touch the renderer, the backend is replaceable behind that interface. Odin ships bindings for WebGL2 (`vendor:wasm/WebGL`), SDL3's GPU API, wgpu, Vulkan and raw OpenGL besides raylib (`~/opt/odin/vendor/`). raylib stays the native choice until a stage fails to fit the Deck's budget, and that is measured, not assumed.

### Open

- The material library's size and the wear rule: a small set with parameters, or per family presets. Decided when the first three machine families are modelled.

## The underground

Direction (user, 2026-10-18, in chat, not yet in the definition): the underground is part of the early game as the factory's bootstrap and of the late game as where the high end rare loot is. Machines stand both in caves and on the surface (user, 2026-10-18), so the early factory spans both levels rather than moving from one to the other. Mine oh Belowed never gave it attention, so nothing transfers beyond its cave generation.

What it fixes already:

- The renderer. The first playable is lit both ways: the sun and sky on the surface, and below ground darkness from the voxel light (sky light fading with depth, coloured block light) with light from lamps and glowing flora, many of both in a bootstrap factory. Clustered lighting is therefore stage 1 above. Volumetric fog stays stage 3.
- The look. Techtonica's cavern glow applies after all, as the early game's light. The surface is the sun's.
- Worldgen. Caves with glowing flora exist from the first chunk, and resources tier by depth: the bootstrap ores in cave walls near the surface, the rare finds deep. The worldgen module already hands the engine the game's records per chunk, the depth tiers are data inside it.
- Logistics. With machines on both levels, moving items between the surface and the caves is an early game need, not a late one. What carries them (belts up a dug shaft, a lift, something else) is game design for the definition.
- The start (user, 2026-10-18). The player starts on the surface and digs down with powered pickaxes. Techtonica's M.O.L.E. is the reference, less magical: the pickaxe breaks terrain, it does not make it vanish into a singularity. Digging is the player module writing blocks through the natives, so the tool's feel (swing, break, rate, power draw) is module and data, nothing in the engine.

The first playable's spine follows: land on the surface under the sun, take the powered pickaxe, dig down, bring ore up from a cave lit by its flora, place the first machines above and below.

### Open

- What the rare loot is and how finding it works. Deferred by the user, game design for the definition first.

## Asset storage

Works out: the definition's Open item on asset storage, Dropbox and Git LFS.

Decided 2026-10-18 (user): two tiers, because the two kinds of files behave differently. Shipped assets start on GitHub hosted LFS to get going, with a self hosted LFS server as the target down the line. The user expects the shipped game's assets to reach at least 1 GB.

### Shipped assets: Git LFS on GitHub

What the game loads from `data/` lives in the repository, binaries as Git LFS objects, on GitHub where heimdall and Mine oh Belowed already live. `.gitattributes` routes images, audio, models and fonts to LFS, by extension, and is the one place the routing lives. Text formats (sjson, GLSL, obj, mtl) stay plain so diffs and agents keep reading them.

- Scale: the only measured point is Mine oh Belowed, whose `data/` is 13 MB after ten days and 606 commits (2026-09-26 to 2026-10-05), its repository 33 MiB packed, with parametric textures and small voxel models. Bedrock Array runs longer and ships physically based texture sets, music and voice, so it will weigh far more. The user's estimate is at least 1 GB shipped. GitHub's free plan includes 10 GiB of LFS storage and 10 GiB of bandwidth a month, overage at $0.07 per GiB stored and $0.0875 per GiB downloaded (GitHub's billing docs, read 2026-10-18). Bandwidth is the one to watch: every fresh clone, CI run or Deck install downloads the objects, so at 1 GB of assets the included bandwidth is about ten full fetches a month. CI caches its LFS objects between runs and the Deck gets copies of the built tree, not clones. The spending limit is set knowingly, not left at its default.
- The move to the self hosted server is cheap because LFS pointers never change: the objects are copied over and the LFS URL in the repository changes, with no rewrite of history. Which server, and where it runs, is decided when the move comes.
- The couch and Deck installs copy the built `data/` tree as plain files, so the players' machines never need LFS.

### Working files: Dropbox, plain

The generators' output, the iteration rounds, the prompts beside their images (the global rule), the art book sources, Blender and DAW projects. They are append only by nature, each round a new file, and nobody diffs them. They go into a Dropbox folder organised per asset, never into git. Dropbox's own file history covers accidents. The Dropbox client is installed as a flatpak here, but no synced folder was found on this machine, so that setup is still to do.

When an asset is chosen for the game, it is copied into `data/` with a small sidecar (the final prompt, the generator and its version, the round's folder name), so a shipped asset can be regenerated or traced back without opening Dropbox.

### Rejected

- Dropbox as the LFS store (lfs-folderstore, dormant since December 2023, or lfs-dal). It works for one machine, but every clone then needs the agent configured and Dropbox credentials, which CI and a Deck install do not have, and `git clone` stops being plain.
- git-annex with an rclone special remote to Dropbox. Good at this exact problem, but its unlocked files and annex metadata are a second workflow for the agents and the build, and the game build path expects plain files.
- Perforce, Anchorpoint, Diversion. Team tools whose value is locking and an artist's client. One person with agents needs neither, and Perforce's free tier evidence is from 2018.

### Open

- The self hosted LFS server: which implementation and which machine. Decided when GitHub's quota starts to pinch.
- Whether the art book's finished pages are shipped assets (in game, through the databank or a journal) or working files. Game design for the definition.

## The Techtonica study

Works out: "Check for solutions in techtonica via Ghidra MCP" in the definition's Research section.

### What the install shows

Read 2026-10-18 from the Steam install on this machine (build 20273707, 6.9 GB on disk): Unity 2022.3.33f1 on Mono (a `MonoBleedingEdge` folder, `Managed/Assembly-CSharp.dll` of 7.1 MB, no IL2CPP `GameAssembly.dll`), the built in render pipeline with the Post Processing Stack v2 (no URP or HDRP assemblies), 110 scene files, 85 MB of Addressables bundles, FMOD banks of 118 MB music, 47 MB effects and 216 MB voice.

The third party assemblies say how it is built: Rewired for input, FMOD for audio, Mirror with kcp2k and Facepunch transports for multiplayer, Facepunch.Steamworks, Cinemachine, GPUInstancer for instanced drawing, Boxophobic's Atmospheric Height Fog and The Vegetation Engine, Space Graphics Toolkit for the sky, Opsive's Ultimate Character Controller for the player and inventory, Addressables, Burst with Collections and Mathematics for jobs, MessagePack for serialisation, PlayFab and GameAnalytics for telemetry, TextMeshPro, Timeline.

### The tools

- Code: ILSpy's command line (`ilspycmd`, a dotnet global tool) over `Assembly-CSharp.dll` gives readable C#, near the source. Not Ghidra: Mono IL decompiles, and Ghidra would only reach the native player or the Burst compiled jobs, whose IL is in the same assembly. The definition's Research line should say ILSpy. A Ghidra MCP is not needed.
- Assets: AssetRipper (standalone Linux build) exports the Addressables bundles and the scenes: the ScriptableObjects (recipes, machine definitions, M.O.L.E. modes), Rewired's input manager data (the exact action maps and layouts), prefabs (footprints, colliders, the light components of cave scenes), materials and shader names, the post processing profiles. UnityPy, through uv in a project venv, for scripted extraction of one asset type.
- Audio: `strings` over `Master.strings.bank` yields only path fragments ("Biome Playlist Music", "Intense Music", "Narrative Music"), so the event tree needs an FMOD bank reader. The tree and the variant count per event are what we want.
- On this machine: python3 only. dotnet comes from Homebrew (10.0.401), `ilspycmd` through `dotnet tool`, AssetRipper as a download.

### Where and how

The decompiled source and the exports live in `work/techtonica/`, outside git, and are never committed. Findings go into `doc/` as mechanisms and numbers, each with the class or asset it came from, so a later reader can check it without redoing the export.

The boundary: the study reads for mechanisms, numbers and structure. No code, asset, text, character or name from Techtonica enters Bedrock Array.

### The questions

Each becomes a work item.

1. Belts: speed per tier, item spacing, how items are stored per segment, the lane model, splitting and merging, and how the items are drawn (GPUInstancer is the suspect).
2. Machines: the grid cell size, footprints and blocked areas per machine, placement and snapping rules, rotation.
3. Controls: Rewired's maps, the actions, categories and per screen layouts, the holds and repeats, and how the Steam Controller reaches the game (XInput on Windows, Steam Input on top).
4. The M.O.L.E.: radius, rate, modes, charge, how the removal is applied to the terrain field and how resources are credited.
5. Terrain: the field representation, chunk size, meshing, LOD, the Burst jobs involved, how a dig propagates to meshes and collision.
6. Lighting and look: the rendering path from the graphics settings, light counts and ranges in cave scenes, bloom, grading and ambient occlusion in the post profiles, fog, and the shader families on machines and terrain. This is what stylised realism is made of technically, and it feeds the renderer's stage 1.
7. Audio: the event tree, variants per event, the music structure (biome playlists, intensity layers, narrative cues).
8. Pacing: early game recipe rates and tiers, how fast the bootstrap goes. Reference only.

Not studied: networking, saves, telemetry.
