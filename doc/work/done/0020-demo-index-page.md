# 0020: The demo index page

Status: landed (2026-10-18, e8a5477)

Goal: the page at the host's root lists every tech demo as a card with its name and a description of what it shows and how to drive it, and every demo page carries a link back to it, so the phone and the laptop have one place to start from (user, 2026-10-18: "Can we get some index page for all tech demos").

Verify:
- `tools/install_web_build.sh` installs an index with a card per demo and the description text; every demo page shows the link in its top left corner (the user).

## Specification (main agent, 2026-10-18)

- `src/demos/<name>/description.txt`: one paragraph per demo (what it shows, what to try), read by the install script from the archive it builds; a demo without the file gets a card with an empty description.
- `tools/install_web_build.sh`, `write_index`: a card (`<a class="demo">` with an `h2` and a `p`) per demo, a line of intro under the title, the commit footer as before.
- `web/index.html`: a fixed `demos` link in the top left corner over the canvas, styled in `web/style.css`, half transparent so it costs the picture little.

Verify: `tools/install_web_build.sh` and the served index; `./build.sh check`.
