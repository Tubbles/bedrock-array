#!/usr/bin/env python3
"""Paint a machine's art book entry and repaint its blockout renders into concept art (doc/workflows/art_book.md, steps 0, 3 and 4).

    tools/art/concept.py <id> --round <n> [--model banana] [--seeds 7 11 19] [--dry-run]
    tools/art/concept.py <id> --turnaround <hero image> --round <n> [--model banana] [--dry-run]
    tools/art/concept.py <id> --entry --round <n> [--model banana] [--seeds 7 11] [--dry-run]

The prompt is composed from the brief (data/machines/<id>/brief.sjson) and its family's style
(data/art/families.sjson), never written by hand. The hero round repaints work/art/<id>/blockout/hero.png
once per seed into work/art/<id>/round-<n>/; the turnaround repaints each orthographic render with the
chosen hero as the second reference into work/art/<id>/round-<n>/turnaround/<view>.png. The entry round
paints a page of the art book from data/art/book.sjson and the brief's entry into the kept template
data/art/page.png, its one reference, once per seed into work/art/<id>/entry-<n>/.
--dry-run prints the prompt and the calls without calling the API.
"""
import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "materials"))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))

import generate  # noqa: E402
import sjson  # noqa: E402

VIEWS = ["front", "left", "back", "right"]
RATIO = "1:1"  # the blockout renders are square; a repaint keeps the reference's camera
ENTRY_RATIO = "4:3"  # the entry illustration


def read_sjson(path):
    with open(path) as source:
        return sjson.parse(source.read())


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def read_brief(machine):
    path = os.path.join(ROOT, "data", "machines", machine, "brief.sjson")
    if not os.path.isfile(path):
        fail(f"no brief: {os.path.relpath(path, ROOT)}")
    return read_sjson(path)


def read_style(family):
    families = read_sjson(os.path.join(ROOT, "data", "art", "families.sjson"))
    if family not in families:
        fail(f"no family {family!r} in data/art/families.sjson")
    return families[family]["style"]


def read_book():
    path = os.path.join(ROOT, "data", "art", "book.sjson")
    if not os.path.isfile(path):
        fail("no data/art/book.sjson")
    return read_sjson(path)


def require_files(paths):
    """Every reference of the command exists before the first paid call."""
    missing = [path for path in paths if not os.path.isfile(path)]
    if missing:
        fail("missing reference: " + ", ".join(missing))


def as_sentence(text):
    text = text.strip()
    return text[0].upper() + text[1:] + ("" if text.endswith(".") else ".")


def figure_sentence(figure):
    """The grey capsule of the blockout is a stand-in: painted as the book's astronaut, at its height and place."""
    return f"The grey capsule beside the machine is a stand-in for {figure}: paint it as that astronaut, at the same height and place."


def hero_prompt(style, brief, figure):
    return " ".join([
        style,
        "Repaint this blockout as finished concept art, keeping its silhouette, proportions and camera exactly as they are.",
        figure_sentence(figure),
        as_sentence(brief["silhouette"]),
        as_sentence(brief["feature"]),
        "No text, no logos.",
    ])


def turnaround_prompt(style, view):
    return (f"{style} Repaint the first image, a flat orthographic {view} elevation of the machine's blockout, as finished "
            f"concept art in exactly that view: no perspective, the camera, silhouette and proportions of the first image. "
            f"The second image is the finished hero view of the same machine: take its materials, colours and details from it, "
            f"not its camera. Add no astronaut. No text.")


def number_text(value):
    """A number as the prompt prints it, without trailing zeros: 2 not 2.0."""
    return f"{value:g}"


def entry_prompt(book, brief):
    if "entry" not in brief:
        fail(f"no entry in the brief of {brief['id']}")
    footprint = brief["footprint"]
    width, depth = (number_text(cells * footprint["cell_metres"]) for cells in footprint["cells"])
    envelope = f"{width}x{depth}x{number_text(brief['height_metres'])} m"
    machine = (f"The entry shows the {brief['id']}, a machine filling {envelope}, {brief['entry']}, "
               f"beside {book['figure']} for scale. The machine reaches up to "
               f"{reach_text(brief['height_metres'], brief['figure_metres'])} of the astronaut.")
    return " ".join([book["pitch"], machine, book["presentation"]])


def reach_text(height, figure):
    """The machine's height against the figure, in words: the one size the models draw (user, 2026-10-18)."""
    ratio = height / figure
    for limit, words in ((0.3, "knee height"), (0.45, "hip height"), (0.65, "torso height"),
                         (0.8, "shoulder height"), (1.05, "head height")):
        if ratio < limit:
            return words
    return "above the head"


def art_directory(machine):
    return os.path.join(ROOT, "work", "art", machine)


def view_render(machine, view):
    return os.path.join(art_directory(machine), "blockout", f"{view}.png")


def call(model, prompt, seed, references, dry_run, ratio=RATIO):
    """One image call; returns (images, cost, seed), or None on a dry run."""
    if dry_run:
        return None
    images, cost, seed = generate.generate_openrouter(model, prompt, 1, ratio, seed, references)
    if not images:
        sys.exit("the model returned no image")
    return images, cost, seed


def describe(model, seed, references, out, ratio=RATIO):
    relative = [os.path.relpath(path, ROOT) for path in references]
    print(f"call: model={model} ({generate.OPENROUTER_MODELS[model]}) seed={seed} ratio={ratio} references={relative} out={os.path.relpath(out, ROOT)}")


def write_view(out, view, model, prompt, images, cost, seed):
    """The turnaround's one image as <view>.png, logged to prompt.txt in generate's format."""
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as target:
        target.write(images[0])
    cost_text = f"${cost:.3f}" if isinstance(cost, (int, float)) else "cost unknown"
    with open(os.path.join(os.path.dirname(out), "prompt.txt"), "a") as log:
        log.write(f"{model} seed={seed} ratio={RATIO} {cost_text}\n{prompt}\n{os.path.basename(out)}\n\n")
    return cost_text


def hero_round(machine, round_number, model, seeds, dry_run):
    brief = read_brief(machine)
    prompt = hero_prompt(read_style(brief["family"]), brief, read_book()["figure"])
    print(prompt)
    out = os.path.join(art_directory(machine), f"round-{round_number}")
    references = [os.path.join(art_directory(machine), "blockout", "hero.png")]
    require_files(references)
    for seed in seeds:
        describe(model, seed, references, out)
        result = call(model, prompt, seed, references, dry_run)
        if result:
            written, cost_text = generate.write_images(out, model, prompt, RATIO, *result)
            print(cost_text, *written)


def entry_round(machine, round_number, model, seeds, dry_run):
    prompt = entry_prompt(read_book(), read_brief(machine))
    out = os.path.join(art_directory(machine), f"entry-{round_number}")
    references = []
    print(prompt)
    for seed in seeds:
        describe(model, seed, references, out, ENTRY_RATIO)
        result = call(model, prompt, seed, references, dry_run, ENTRY_RATIO)
        if result:
            written, cost_text = generate.write_images(out, model, prompt, ENTRY_RATIO, *result)
            print(cost_text, *written)


def turnaround(machine, round_number, model, hero, views, dry_run):
    style = read_style(read_brief(machine)["family"])
    hero = os.path.abspath(hero)
    require_files([view_render(machine, view) for view in views] + [hero])
    out_directory = os.path.join(art_directory(machine), f"round-{round_number}", "turnaround")
    for view in views:
        prompt = turnaround_prompt(style, view)
        print(prompt)
        references = [view_render(machine, view), hero]
        out = os.path.join(out_directory, f"{view}.png")
        describe(model, None, references, out)
        result = call(model, prompt, None, references, dry_run)
        if result:
            print(write_view(out, view, model, prompt, *result), out)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("machine", help="the brief's id, data/machines/<id>/brief.sjson")
    parser.add_argument("--round", type=int, required=True, dest="round_number")
    parser.add_argument("--model", choices=generate.OPENROUTER_MODELS, help="default: the brief's art.model")
    parser.add_argument("--seeds", type=int, nargs="+", help="the hero round's seeds, default 7 11 19; the entry round's, default 7 11")
    parser.add_argument("--turnaround", metavar="HERO", help="the chosen hero image; repaints the orthographic views")
    parser.add_argument("--views", nargs="+", choices=VIEWS, default=VIEWS, help="the turnaround's views, default all four; a failed view is rerun on its own")
    parser.add_argument("--entry", action="store_true", help="paint art book entries from data/art/book.sjson and the brief's entry")
    parser.add_argument("--dry-run", action="store_true", help="print the prompt and the calls, call nothing")
    arguments = parser.parse_args()
    if arguments.turnaround and arguments.seeds:
        parser.error("--seeds applies to the hero round, not to --turnaround")
    if arguments.turnaround and arguments.entry:
        parser.error("--entry and --turnaround exclude each other")
    model = arguments.model or read_brief(arguments.machine)["art"]["model"]
    if arguments.entry:
        entry_round(arguments.machine, arguments.round_number, model, arguments.seeds or [7, 11], arguments.dry_run)
    elif arguments.turnaround:
        turnaround(arguments.machine, arguments.round_number, model, arguments.turnaround, arguments.views, arguments.dry_run)
    else:
        hero_round(arguments.machine, arguments.round_number, model, arguments.seeds or [7, 11, 19], arguments.dry_run)


if __name__ == "__main__":
    main()
