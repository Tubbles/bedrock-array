# 0040: Carry the image tool and the family styles

Status: landed (2026-10-18, 3ba9c6f)

Goal: step 3 of `doc/workflows/art_book.md` needs the image tool: Mine oh Belowed's `tools/art/generate.py` copied at its commit 66b863c with a README naming the source, as the project copies rather than submodules, and the first family style paragraph in `data/art/families.sjson` (the furnace family, composed into every prompt of the smelter). Refers to item 0038.

Verify:
- `python3 -I -c "import ast; ast.parse(open('tools/art/generate.py').read())"` parses; `data/art/families.sjson` parses with the tools' reader and holds `furnace`.
