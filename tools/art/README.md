# tools/art

`generate.py` is a copy of Mine oh Belowed's `tools/art/generate.py` at its commit 66b863c ("Send reference images the way the images API takes them"), carried over as a copy rather than a submodule, as the project does with its shared collections. It takes a prompt, an optional seed and reference images, calls an image model through OpenRouter (the key at `~/.config/openrouter/key`) or fal, writes every image beside a `prompt.txt` that records the model, the seed, the cost and the prompt. The workflow that uses it is `doc/workflows/art_book.md`.
