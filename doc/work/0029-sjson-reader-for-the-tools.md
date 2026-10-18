# 0029: An SJSON reader for the tools

Status: implementing (2026-10-18)

Goal: the material scripts of `doc/workflows/materials.md` run inside Blender's Python and read the project's SJSON files (the bake parameters, `data/materials/library.sjson`), which no Python library parses. A small reader with no dependencies, so it runs in Blender's bundled Python and the system Python alike. Refers to item 0028.

Verify:
- `python3 -m unittest discover -s tools/materials -p '*_test.py'` passes.

## Specification (main agent, 2026-10-18)

- `tools/materials/sjson.py`: `parse(text: str) -> dict`, the Bitsquid simplified JSON the project's data files use (`core:encoding/json` with `Specification.SJSON` reads them in Odin): an implicit root object, keys as bare identifiers or quoted strings, `=` or `:` between key and value, commas optional between members and elements, `//` line comments and `/* */` block comments, values as objects `{}`, arrays `[]`, strings in double quotes with the JSON escapes, numbers (an optional sign, digits, an optional fraction and exponent, read as `int` when they have neither fraction nor exponent, else `float`), `true`, `false`, `null`. A tokenizer and a recursive descent parser, each procedure short. A parse error raises `SjsonError` with the line number and what was expected. Nothing else: no triple quoted strings, no writing.
- `tools/materials/sjson_test.py`: `unittest` cases for a material preset in the library's form (`painted_steel = { albedo = [0.20, 0.24, 0.30] roughness = 0.55 metallic = 0 }`, no commas), the comment forms, a quoted key with a `:`, nested arrays, the int and float distinction, `true`, `false`, `null`, a string escape, and three errors (an unterminated object, a missing value, a stray comma at the root), each asserting `SjsonError` and the line number.
- `tools/materials/__init__.py` is not needed: the test imports `sjson` with the directory on the path, which `unittest discover -s tools/materials` gives it.

Verify: `python3 -m unittest discover -s tools/materials -p '*_test.py'`, and `python3 -c "import sys; sys.path.insert(0, 'tools/materials'); import sjson; print(sjson.parse(open('data/materials/library.sjson').read())['painted_steel'])"` prints the preset.
