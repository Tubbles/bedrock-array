# 0119: Messages and text in the editor

Status: implementing (2026-10-20)

Goal: a step's failure message is read in full, and the string keys (a source path, a part name, a note, a selection's pieces and parts) are edited in game (user, 2026-10-20: "i need a way to see the messages and edit strings").

Verify:
- Tests of the text field's editing (insert, delete, cursor, accept, cancel); shots of a long failure message and of a string being edited.

## Specification

- The selected step's message (failure or status) shows in a panel under its plaque, wrapped to the panel's width (the app's `wrap_words`), never clipped.
- The key panel offers the string keys: Enter on one opens a text field (raylib `GetCharPressed` for typing, Backspace, Delete, the arrows, Home and End, Enter accepts, Escape cancels); a key with known values (a part name, a technique, a front) cycles through them with left and right instead, with the field still available for a new part name. On the pad a string key cycles its known values only.
