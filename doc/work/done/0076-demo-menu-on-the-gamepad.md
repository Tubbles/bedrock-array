# 0076: The demo menu on the gamepad

Status: landed (2026-10-19, f0e4480)

Goal: the gamepad is all the couch needs (user, 2026-10-19): a menu lists the demos, the d-pad or the left stick moves, South enters a demo, East (or Start) leaves it back to the menu, East on the menu quits. The keyboard mirrors it (arrows, Enter, Escape).

Verify:
- `./build.sh debug`, `check`, `test` and `smoke` pass; the smoke run now runs the binary twice, three frames of the menu and three of `--demo models`, both with no error line.
- `test_menu_step` passes: down moves the row and wraps, up from the first row wraps to the last, select gives Enter, back gives Leave.
- `test_menu_edges` passes: a button held over two polls counts once, the stick past 0.5 counts once until it returns inside.

## Specification

- `src/app/menu.odin`: `App_Screen :: enum { Menu, Demo }`; `Menu_State :: struct { row: int }`; `Menu_Input :: struct { up, down, select, back: bool }`; `Menu_Command :: enum { None, Enter, Leave }`; `menu_step(state: ^Menu_State, count: int, input: Menu_Input) -> Menu_Command`: up and down move the row with wrap, select gives `.Enter`, back `.Leave`, the row moves before the command is read; `Menu_Edge_State :: struct { buttons: bit_set[Gamepad_Button], stick_out: bool }` and `menu_edges(state: ^Menu_Edge_State, snapshot: Gamepad_Snapshot) -> Menu_Input`: a button counts on the poll it appears in (`snapshot.buttons - state.buttons`), `Dpad_Up` up, `Dpad_Down` down, `South` select, `East` back, and the left stick's y past minus 0.5 counts as up and past plus 0.5 as down once, until it returns inside; `menu_draw(state: Menu_State, demos: []Demo, stamp: string)`: the title, one row per demo with its name and description, the current row highlighted, the glyph line `A enter, B quit` at the bottom and the stamp in a corner, through `rl.DrawText` in screen points scaled by the screen height over 720.
- `src/app/main.odin`: `Options.demo` defaults to empty, which starts on the menu, and `--demo <name>` starts in that demo; the keys give a `Menu_Input` too (`rl.IsKeyPressed` of Up, Down, Enter, Escape) ORed with the pad's; the screen starts on `.Menu` with the cursor enabled; `.Enter` initialises the row's demo view (the previous one destroyed first) and switches to `.Demo` with the cursor disabled; in a demo East, Start or Escape (edges) gives `.Leave`, which destroys the view and returns to the menu with the cursor enabled; `.Leave` on the menu ends the loop, as `rl.WindowShouldClose` and `--frames` do; `should_continue` no longer reads Escape. The GL error check after the first frame stays.
- `build.sh`, `smoke_app`: the run happens twice, `--frames 3` and `--demo models --frames 3`, each checked the same way.
- `src/app/menu_test.odin`: the two tests above.
- `doc/build.md`: the controls in one paragraph, pad first, keys second, and the smoke paragraph says two runs.
