# Bedrock Array

Bedrock Array -- A placeholder name that has potential to not be merely a placeholder.

A game heavily inspired by Techtonica. It draws from it without shame. Great artists steal.

My recent attempt at a similar game also feeds into this: Mine oh Belowed. It failed though because the art direction started out as Minecraft + Manufactio rather than Techtonica. That project still holds some valuable pieces and lessons learned:

1. Bad placeholder art affects the development process deeply. If it looks like its drawn by a toddler then immediately it will start feeling like its low quality. This holds true also for text interactions with "the venture" / mission control, where they felt very low quality, almost one-line punches from a 90's sitcom, they felt a littel fun initially, but when every single interaction was like that it grows old REALLY fast.
2. The planet worlds are good, lets bring those over to this project.
3. Claude code can't design assets, like at all. We need to come up with specialized work flows for each asset type, which in and of themselves are almost like their own projects with iterations and scrutinization. More on this further down.
4. Generally bring over a lot of the stuff from mine oh belowed. We did a lot of great things there.

From techtonica: High quality and polish, machine sizes, gamepad oriented interactions. I love to see the little items travel along belts.

Other inspiration: * Factorio * Dyson sphere program * Satisfactory * Planet crafter * Minecraft. Look at mine-oh-belowed/doc/inspiration.md for more, especially Techtonica's controls and screens.

Warcraft 3 mapping API and world editor. This was genius for its time. It allowed creators to freely use the vast wealth of warcraft assets while sporting a massive scripting engine. This was so influential that whole game genres spawned from it (eg MOBA). I want that deep modifiability for this project. That means the modding API needs to allow for a mod to design completely new game systems and mechanics. The API needs to reach deep, allowing for modifying the camera and reading raw inputs such as mouse movement and keyboard presses (called 'Natives' in Wc3).

## Design

No violence. If people want violence they will have to write mods themselves for it. The modding API will cater to that kind of content being added.

Realistic rather than cartoonish.

Odinlang + Raylib. Mods shall also be written in odinlang using wasm. See my other projects Heimdall and Mine oh Belowed. This project's core game shall also be implemented in multiple wasm modules, in order to dog-food the modding API, similarly to how Wc3 did it. That means world generation, machine and vehicle functionality.

Gamepad as a first class citizen with full support for the 2026 Steam Controller. Again see Mine oh Belowed for how this was achieved. The extra buttons and functionality from SC shall be fully utilized, but bound to "quality of life" features: the whole game and core experience shall be available for a standard xbox style gamepad. That means that things like L4/R4 on SC could be bound to "turn 90 degrees left/right", or as quick shortcuts to shortcuts normally reached through dial-selection rings or other widgets. Input layer fully rebindable through UI. In game editor mode, also fully navigable from a gamepad, look at my other project "sleipner" for some inspiration, such as an in game string builder and trigger/script designer.

Data-heavy game design using SJSON, directly modifiable from in game, via the editor mode.

Lessons learned from Mine oh Belowed: For a game to be fully LLM generated, we need to develop specific asset workflows for everything. Standard claude code is good for coding, but everything else needs either special harness/MCP/skills or AI models from other vendors outright. Designing these workflows demand careful attention and big effort. Just slapping some synthesizer mcp to opus is not good enough for sound effects. I'm talking doing deep research into what the current state of the art is, are there recent breakthroughs of some good asset workflows with AI. Pipelines that need workflows: 1) Art book, artistic drawings of in game mechanics and events. 2) Music direction and design. 3) Sound effects, animal sounds etc. 4) Voice synthesis. 5) Modelling (probably Blender MCP or FreeCAD MCP here).

Copying from Mine oh Belowed: * Open world, procedurally generated, star system navigation, ground digging, smooth voxel planets, tangential "forward" vector. * Smooth blending between planet surface and space travel not needed, it can be tastefully hidden behind rocket -> orbit travel, but without being a cutscene: the player can look around in their rocket seat, strapped in and with EVA gear on. * Pools for biome types, flora and fauna.

Drop from Mine oh Belowed: * All the game design, the models, art book, string assets, lore, gameplay phases etc.

## Open

We need to research asset storage solutions. We could use my private dropbox account as a starter backend. How do game studios usually solve this? Git LFS?

## Research

Look for relevant MCPs and skills and use them. Read through Mine oh Belowed main documentation. Check for solutions in techtonica via Ghidra MCP. Research the rest of the inspirations listed in this document. Search online for what makes each of these games great.

## First order of business

Read this document and internalize it, adapt it into our project structure such as PLAN.md, doc/work items etc.

Utilize subagents but make sure their work is bounded: each step (design, implement, review, etc) but make sure to trim the size of the work items so that each step takes roughly 1 minute max. Eg. for a design-implement-review cycle no more than 3 minutes shall pass. Continuously evaluate this to find a good work item size, if eg. a implementation step takes 3 minutes, try cutting the amount of implementation work by half. This is because I don't want to wait a long time during iteration. This means that most of the time you will be chopping up larger work pieces into commit-sized items. This rule is not very hard: its not an issue if a cycle step takes a couple extra minutes once in a while, its the average that is important, along with it not balooning into 10+ minutes for a single step.

Initialize git repo and set up the file structure.

Get to a playable state quickly so we can start iterate.

Look at mine-oh-belowed for how to integrate this checkout into steam game mode. Also make it easy for me to get this onto my steam deck somehow.
