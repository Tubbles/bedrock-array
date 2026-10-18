# Bedrock Array: instructions for LLM agents

Read this together with the global `~/.claude/CLAUDE.md`. This file holds the project's rules for agents. The intent is [definition.md](definition.md) (the user's text, agents never edit it), the decisions are [DESIGN.md](DESIGN.md), the way there is [PLAN.md](PLAN.md), the details enter through [doc/README.md](doc/README.md).

## Stack

- Language: Odin. Toolchain at `~/opt/odin` (dev-2026-09 nightly). Do not install another Odin.
- Phase A, the tech demos: Odin built with `-target:js_wasm32` to wasm for the browser, rendering through `vendor:wasm/WebGL` (WebGL2 calls only, never WebGL1), the toolchain's `core/sys/wasm/js/odin.js` runtime copied into the build, the page shell under `web/`. One package per demo under `src/demos/<name>/`; the engine packages under `src/engine/` compile natively for their tests and to wasm for the pages.
- Phase B, the native engine: raylib 6.0 through the repository collection `shared:raylib`, archive committed, built by `tools/build_raylib.sh` (carried from Mine oh Belowed). Never import `vendor:raylib`. Controller input: SDL3 through `vendor:sdl3`, joystick and gamepad subsystems only, never video (carried from Mine oh Belowed's input layer).
- Wasm host: wasmtime through `shared:wasmtime` and `shared:wasm`, copies of the user's `odin-wasmtime-bindings` and `odin-wasm-bindings` with the source commit recorded in each README. Copies, not submodules (user, 2026-10-18), so clones, CI and agents need no submodule step.
- Content: SJSON under `data/`, parsed with `core:encoding/json` as `Specification.SJSON`. Never hardcode a material, block, machine or recipe in Odin code.
- Build and verify through `build.sh` (`check`, `test`, `web <demo>`, later `debug` and `release`), which passes the collections; a bare `odin check src` does not compile. Sessions are headless: nothing opens a window or a browser, the user explores the pages. After every commit on `main` the web build is installed (`tools/install_web_build.sh`, item 0003) and the reply names the installed commit and the page URL.
- Licence: AGPL-3.0 for everything (user, 2026-10-18).

## Layout

The global project structure, plus: `src/engine/` (one package, `engine`, split into files by concern, `render_*`, `field_*` and so on; web only files carry the `#+build js` tag so native checks and tests skip them), `src/demos/<name>/` (the tech demos of phase A, one package each), `src/modules/<name>/` (the wasm modules of phase B), `web/` (the page shell: HTML, CSS and the small JS glue for what the Odin runtime lacks, audio, gamepad, resize, each in one file), `shared/` (collections), `tools/`, `data/` (`data/materials/` is the material library every demo and module shares, `data/demos/<name>/` a demo's own scene data), `bin/web/` the installed pages the host serves to the LAN, later `bin/play/` the play build. `work/` and `tmp/` are untracked. Work items under `doc/work/`, landed ones under `doc/work/done/`, closed ones under `doc/work/cancelled/`. `TODO.md` is the user's inbox, `SUGGESTIONS.md` holds only decisions the user must make.

## Code rules

- Odin conventions: `snake_case` procedures and variables, `Ada_Case` types, `SCREAMING_CASE` constants. Full words, no abbreviations.
- Small pure procedures, structs as data carriers, arrays of structs, no OOP.
- Engine code is engine grade from the first demo: kernels are pure procedures with tests, and the renderer is driven by draw lists only. A demo builds a draw list and hands it over, never reaches into the renderer. What the demos settle moves into the engine phase, not rewritten.
- A page works with touch, with mouse and keyboard, and with a gamepad through the Gamepad API where it applies, and its layout fits a phone in portrait as well as a laptop.
- Module code compiles both ways: a module is a plain Odin package, built to wasm for the shipped game and natively for its tests and the fused debug build. The couch build runs the wasm build.
- Test files carry `#+build !js` because the test library does not exist for the browser, and web only files carry `#+build js wasm32`.
- Across the wasm boundary only fixed layout structs without pointers (DESIGN.md, The natives), no host call per entity per tick, outputs as views.
- The simulation is deterministic: fixed tick, seeded, integer or fixed point in simulation state, no wall clock. Rendering interpolates and the simulation never reads the frame time.
- No perceivable repetition (the global memory principle, DESIGN.md): every new sound, animation and texture is checked before it lands.
- Placeholders are primitives in library materials under the real light, never improvised art, and a text not yet written is absent, not a quip (DESIGN.md, Placeholders).
- Documentation is updated in the same commit as the behaviour it describes, in the doc that owns the topic, one place per fact. Decisions go to `doc/log/YYYY-MM-DD.md`.
- Review and commit language: plain engineering vocabulary, see the global instructions.

## Work flow

Serial (user, 2026-10-18), one subagent at a time, Opus 5.5 for implementers and reviewers.

1. The main agent explores and writes the item's specification itself: the files and procedures to add or change, the behaviour, the data keys, the tests by name, the verify command. An implementer never explores. A design agent runs only for an item with a real seam decision.
2. The implementer edits the main checkout, runs the touched package's tests, never commits, reports with any deviation and its reason.
3. A fresh reviewer reads the working tree diff against the item, runs the suite and what the implementer did not, reports findings ranked by severity with file and line, each confirmed or plausible, then what it ran. It never edits.
4. The main agent weighs the findings, resumes the same implementer for a fix round or fixes trivia itself, runs the suite once, commits, installs the play build, moves the item.

### Cadence

The user's rule (definition.md, First order of business): each step about one minute, a cycle about three, the average matters, never a ten minute step.

- The floor of a step is what the agent must read, so the lever is zero discovery: the specification carries everything.
- An item is commit sized: one concern, one to three files, under about 150 changed lines with its test. A specification longer than about ten lines means the item splits. Starting values, tuned by measurement.
- Verify per step is the touched package's tests. The whole suite runs once at landing.
- A follow-up fix goes to the same implementer, which keeps its context. Trivia stays with the main agent.
- The main agent writes the next specification while the current agent runs.
- Measurement: the main agent notes the time a step is spawned and the time its notification arrives, and writes one line per landed item into the day's log (implement and review minutes). When the average of the last five implementation steps drifts above target, the next item is cut in half.

### Items and the status line

`doc/work/NNNN-slug.md`, short: the goal, a `Status` line, a `Verify` list, the `## Specification` once written. The `Status` line is one word and a parenthesis with the date and, once landed, the commit: `todo`, `designing`, `designed`, `implementing`, `implemented`, `verifying`, `verified`, `landed`, `cancelled`. Agent ids go to `tmp/agent_ids.txt`, never into the item. A landed item moves to `doc/work/done/` with `git mv` in a commit of its own. An item is never reopened: follow-up work is a new item that refers to it. Each landed item gets one weighed section in the day's log: what the commit message, the code and the docs do not already say.
