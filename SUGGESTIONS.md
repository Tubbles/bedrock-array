# Suggestions

Decisions the user must make, tradeoffs, and things to measure before deciding. Work an agent sees should be done is not a suggestion: it becomes an item under `doc/work/`.

- The tech demo series in [PLAN.md](PLAN.md) is a proposal. Add, drop or reorder demos before the first one starts.
- What the rare loot deep underground is and how finding it works ([DESIGN.md](DESIGN.md), The underground). Deferred by the user 2026-10-18.
- Whether the art book's finished pages ship in the game or stay working files ([DESIGN.md](DESIGN.md), Asset storage).
- Whether the actions and ui modules merge, decided by the first vertical slice ([DESIGN.md](DESIGN.md), The module side).
- The material library's size and wear rule, decided when the first three machine families are modelled ([DESIGN.md](DESIGN.md), The look and the renderer).
- The self hosted LFS server: which implementation and which machine, when GitHub's quota starts to pinch.
- The licence: AGPL-3.0 for everything for now (user, 2026-10-18). Revisit when the modding API goes public, since mods and mod tooling then sit on an AGPL engine.
- The web host serves plain http on the LAN. If a browser API a demo needs (the phone's gyro, the Gamepad API in some browsers) requires a secure context, the host needs https with a local certificate. Measured when the first such demo comes.
- `definition.md` still names a Ghidra MCP for the Techtonica study and does not yet hold the underground direction, the surface start with powered pickaxes, or machines on both levels. They live in [DESIGN.md](DESIGN.md) and the chat of 2026-10-18.
- The bloom is now a lens scattering chain (item 0027) with a five percent mix and five levels. Whether the veil on the cave page reads as too faint, too strong or too wide is an art direction call: the strength and the level count are the two knobs, in `src/engine/render_webgl.odin`.
- D1's close: the cave and surface pages are the demo's two scenes. Whether they are release quality, and what is missing before they are (shadows are stage 2, the sky model comes with D2's day and weather), is the user's judgement on the phone and the laptop. Clustered lights and vertex ambient occlusion from the D1 row wait for scenes that need them.
