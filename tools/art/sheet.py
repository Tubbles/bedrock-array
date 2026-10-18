#!/usr/bin/env python3
"""Lay out a round's review sheet and print its checks (doc/workflows/art_book.md, step 5).

    tools/art/sheet.py <id> --round <n>

Rows: the blockout hero and four views, the round's repaints, the turnaround views that exist, and
the squint row (every repaint as a 64 pixel greyscale thumbnail, scaled up bilinear). A line at the hero mask's top row
runs across the first two rows. Writes work/art/<id>/round-<n>/review.png and prints one line per
check: <CHECK> <image> <value> ok|warn.
"""
import argparse
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageMath

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "materials"))

import sjson  # noqa: E402

VIEWS = ["front", "left", "back", "right"]
IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")
CELL = 512
LABEL = CELL * 20 // 256
LABEL_FONT = LABEL * 3 // 5
LINE_WIDTH = CELL // 256
SQUINT = 64
LINE_COLOUR = (255, 64, 64)
EDGE_THRESHOLD = 32
EDGE_REACH = 7
PALETTE_DISTANCE = 0.25
BOX_GROWTH = 0.05
SILHOUETTE_OK = 0.85
PALETTE_OK = 0.6
HEIGHT_TOLERANCE = 0.05
STACK_SHARE = 0.05
TOP_ROW_EDGES = 4


def read_sjson(path):
    with open(path) as source:
        return sjson.parse(source.read())


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def read_palette(machine):
    brief_path = os.path.join(ROOT, "data", "machines", machine, "brief.sjson")
    if not os.path.isfile(brief_path):
        fail(f"no brief: {os.path.relpath(brief_path, ROOT)}")
    family = read_sjson(brief_path).get("family")
    if family is None:
        fail(f"no family in {os.path.relpath(brief_path, ROOT)}")
    families_path = os.path.join(ROOT, "data", "art", "families.sjson")
    if not os.path.isfile(families_path):
        fail("no data/art/families.sjson")
    families = read_sjson(families_path)
    if "palette" not in families.get(family, {}):
        fail(f"no palette for family {family!r} in data/art/families.sjson")
    return [tuple(round(channel * 255) for channel in colour) for colour in families[family]["palette"]]


def images_in(directory):
    if not os.path.isdir(directory):
        return []
    names = sorted(name for name in os.listdir(directory) if name.lower().endswith(IMAGE_EXTENSIONS))
    return [os.path.join(directory, name) for name in names if name != "review.png"]


def turnaround_views(round_directory):
    """(view, path) for each turnaround view that exists."""
    by_stem = {os.path.splitext(os.path.basename(path))[0]: path for path in images_in(os.path.join(round_directory, "turnaround"))}
    return [(view, by_stem[view]) for view in VIEWS if view in by_stem]


def open_rgb(path, size=None):
    image = Image.open(path).convert("RGB")
    return image.resize(size, Image.LANCZOS) if size and image.size != size else image


def open_mask(path):
    mask = Image.open(path).convert("L").point(lambda value: 255 if value >= 128 else 0)
    if mask.getbbox() is None:
        fail(f"empty mask: {os.path.relpath(path, ROOT)}")
    return mask


def near_colour(image, colour, distance):
    """L mask, 255 where a pixel lies within distance (sRGB 0..1, Euclidean) of colour."""
    difference = ImageChops.difference(image, Image.new("RGB", image.size, colour))
    red, green, blue = (channel.convert("I") for channel in difference.split())
    limit = int((distance * 255) ** 2)
    near = ImageMath.lambda_eval(lambda arguments: (arguments["r"] * arguments["r"] + arguments["g"] * arguments["g"] + arguments["b"] * arguments["b"]) <= limit,
                                 r=red, g=green, b=blue)
    return near.convert("L").point(lambda value: 255 if value else 0)


def count_set(mask):
    return mask.histogram()[255]


def grown_box(mask):
    left, top, right, bottom = mask.getbbox()
    growth = round(BOX_GROWTH * max(mask.size))
    return (max(0, left - growth), max(0, top - growth), min(mask.width, right + growth), min(mask.height, bottom + growth))


def edges(image):
    """L mask, 255 on the greyscale image's edges."""
    found = image.convert("L").filter(ImageFilter.FIND_EDGES)
    return found.point(lambda value: 255 if value >= EDGE_THRESHOLD else 0)


def outline(mask):
    return ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))


def silhouette_coverage(image_edges, mask):
    """Share of the mask's outline that has an image edge within reach."""
    mask_outline = outline(mask)
    near = image_edges.filter(ImageFilter.MaxFilter(EDGE_REACH))
    return count_set(ImageChops.darker(mask_outline, near)) / count_set(mask_outline)


def palette_share(image, mask, palette):
    near_any = Image.new("L", image.size, 0)
    for colour in palette:
        near_any = ImageChops.lighter(near_any, near_colour(image, colour, PALETTE_DISTANCE))
    return count_set(ImageChops.darker(near_any, mask)) / count_set(mask)


def stack_window(mask):
    """The grown box's rows, over the columns the mask sets in its top STACK_SHARE grown by BOX_GROWTH each side.

    Narrowing to the stack's columns keeps the figure and stray sky edges out."""
    _, top, _, bottom = mask.getbbox()
    stack_rows = mask.crop((0, top, mask.width, top + max(1, round(STACK_SHARE * (bottom - top)))))
    left, _, right, _ = stack_rows.getbbox()
    growth = round(BOX_GROWTH * max(mask.size))
    _, box_top, _, box_bottom = grown_box(mask)
    return (max(0, left - growth), box_top, min(mask.width, right + growth), box_bottom)


def first_edge_row(image_edges, window):
    """The first row of the window with at least TOP_ROW_EDGES edge pixels, or None."""
    left, top, right, bottom = window
    for row in range(top, bottom):
        if count_set(image_edges.crop((left, row, right, row + 1))) >= TOP_ROW_EDGES:
            return row
    return None


def top_offset(image_edges, mask):
    """Signed: the first edge row above the stack minus the mask's top row, over the mask's height."""
    _, top, _, bottom = mask.getbbox()
    row = first_edge_row(image_edges, stack_window(mask))
    return (row - top) / (bottom - top) if row is not None else 1.0


def check_lines(name, image_path, mask_path, palette):
    mask = open_mask(mask_path)
    image = open_rgb(image_path, mask.size)
    image_edges = edges(image)
    silhouette = silhouette_coverage(image_edges, mask)
    share = palette_share(image, mask, palette)
    height = top_offset(image_edges, mask)
    return [
        f"SILHOUETTE {name} {silhouette:.3f} {'ok' if silhouette > SILHOUETTE_OK else 'warn'}",
        f"PALETTE {name} {share:.3f} {'ok' if share > PALETTE_OK else 'warn'}",
        f"HEIGHT {name} {height:+.3f} {'ok' if abs(height) <= HEIGHT_TOLERANCE else 'warn'}",
    ]


def cell_image(path):
    image = Image.open(path).convert("RGB")
    image.thumbnail((CELL, CELL), Image.LANCZOS)
    return image


def squint_image(path):
    small = Image.open(path).convert("L").resize((SQUINT, SQUINT), Image.LANCZOS)
    return small.resize((CELL, CELL), Image.BILINEAR).convert("RGB")


def place_row(sheet, draw, row_index, cells):
    """cells: (label, image) pairs, left to right, centred in their CELL squares."""
    top = row_index * (CELL + LABEL)
    for column, (label, image) in enumerate(cells):
        left = column * CELL
        sheet.paste(image, (left + (CELL - image.width) // 2, top + (CELL - image.height) // 2))
        draw.text((left + LABEL // 5, top + CELL + LABEL // 5), label, fill=(230, 230, 230), font=ImageFont.load_default(LABEL_FONT))


def height_line(draw, row_index, width, mask_top, mask_side):
    y = row_index * (CELL + LABEL) + round(mask_top * CELL / mask_side)
    draw.line([(0, y), (width, y)], fill=LINE_COLOUR, width=LINE_WIDTH)


def build_sheet(rows, mask_top, mask_side):
    width = CELL * max(1, max(len(cells) for cells in rows))
    sheet = Image.new("RGB", (width, len(rows) * (CELL + LABEL)), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    for row_index, cells in enumerate(rows):
        place_row(sheet, draw, row_index, cells)
    for row_index in (0, 1):
        height_line(draw, row_index, width, mask_top, mask_side)
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("machine", help="the brief's id, data/machines/<id>/brief.sjson")
    parser.add_argument("--round", type=int, required=True, dest="round_number")
    arguments = parser.parse_args()
    palette = read_palette(arguments.machine)
    art_directory = os.path.join(ROOT, "work", "art", arguments.machine)
    blockout = os.path.join(art_directory, "blockout")
    round_directory = os.path.join(art_directory, f"round-{arguments.round_number}")
    blockout_names = ["hero"] + VIEWS
    if not all(os.path.isfile(os.path.join(blockout, f"{name}{suffix}.png")) for name in blockout_names for suffix in ("", "_mask")):
        fail(f"incomplete blockout: {os.path.relpath(blockout, ROOT)}")
    if not os.path.isdir(round_directory):
        fail(f"no round: {os.path.relpath(round_directory, ROOT)}")
    repaints = images_in(round_directory)
    views = turnaround_views(round_directory)
    for path in repaints:
        print(*check_lines(os.path.basename(path), path, os.path.join(blockout, "hero_mask.png"), palette), sep="\n")
    for view, path in views:
        print(*check_lines(f"turnaround/{os.path.basename(path)}", path, os.path.join(blockout, f"{view}_mask.png"), palette), sep="\n")
    rows = [
        [(name, cell_image(os.path.join(blockout, f"{name}.png"))) for name in blockout_names],
        [(os.path.basename(path), cell_image(path)) for path in repaints],
        [(view, cell_image(path)) for view, path in views],
        [(os.path.basename(path), squint_image(path)) for path in repaints + [path for _, path in views]],
    ]
    hero_mask = open_mask(os.path.join(blockout, "hero_mask.png"))
    sheet = build_sheet(rows, hero_mask.getbbox()[1], hero_mask.height)
    out = os.path.join(round_directory, "review.png")
    sheet.save(out)
    print(os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
