# 0118: Key hints on screen

Status: implementing (2026-10-20)

Goal: every action the editor offers at a moment is shown on screen with its key and pad button, so nothing has to be remembered (user, 2026-10-20: "all the keybindings need to be visible on screen when they are available").

Verify:
- Tests that each mode's hint list matches the actions its input handling accepts; shots of the hints in the walk, brush, panel and op menu modes.

## Specification

- A pure `editor_hints(editor) -> []Editor_Hint {keys: string (keyboard and mouse), pad: string, action: string}` per mode (walk, brush, key panel, op menu, text field, the unsaved leave warning), from one table that the input handling also reads, so a binding and its hint cannot drift apart. Drawn as a bar along the bottom: one plaque per hint, keyboard first, the pad button after a slash.
- Every action available from the keyboard gets a pad binding (insert, delete, move, enable, part cycle included), through a pad modifier (holding the left shoulder) where buttons run out; the hint shows the combination.
