"""Compose the art book page template, data/art/page.png (doc/workflows/art_book.md, step 0): the pass 3 page under work/art/page-2/ with its too large figure erased and its paper tone matched to the first template, plus the figure of data/art/figure.png cut out and placed at 40 percent of the frame height. A one off with the coordinates of that page, kept so the template can be remade: python3 tools/art/page_template.py [data/art/figure.png]"""
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat

ORIGINAL = "work/art/page/banana_1.png"
PAGE = "work/art/page-2/banana_0.png"
OUT = "data/art/page.png"
PAPER_REGION = (1200, 70, 1800, 140)
FRAME = (410, 240, 1990, 1126)
ERASE_LEFT, ERASE_RIGHT = 1540, 2020
ERASE_TOP, ERASE_BOTTOM = 300, 1340
INTERIOR_SOURCE_LEFT = 1090
LINE_BAND = (1120, 1132)
TONE_BAND = (250, 300)
MARGIN_BAND = (1340, 1392)
FEATHER = 80
FIGURE_SEARCH = (400, 100, 1650, 2000)
RIGHT_LINE_STRIP = (1978, 250, 2016, 300)
FIGURE_HEIGHT_SHARE = 0.4
FEET_Y = 1118
RIGHT_X = 1920


def paper_mean(image, region):
    return ImageStat.Stat(image.crop(region)).mean


def match_paper(image, reference):
    source = paper_mean(image, PAPER_REGION)
    target = paper_mean(reference, PAPER_REGION)
    bands = [band.point(lambda value, scale=target[index] / source[index]: min(255, round(value * scale)))
             for index, band in enumerate(image.split())]
    return Image.merge("RGB", bands)


def region_figure_mask(region, paper):
    """The old figure's pixels by colour distance alone: the frame lines cross the region, so no flood fill."""
    return distance_mask(region, paper).filter(ImageFilter.MaxFilter(11))


def column_paper(page, left, right, height):
    band = page.crop((left, TONE_BAND[0], right, TONE_BAND[1]))
    return band.resize((right - left, 1), Image.BOX).resize((right - left, height), Image.BILINEAR)


def erase_big_figure(page):
    box = (ERASE_LEFT, ERASE_TOP, ERASE_RIGHT, ERASE_BOTTOM)
    region = page.crop(box)
    paper = paper_mean(page, (ERASE_LEFT, TONE_BAND[0], ERASE_RIGHT, TONE_BAND[1]))
    mask = region_figure_mask(region, paper)
    fill = column_paper(page, ERASE_LEFT, ERASE_RIGHT, ERASE_BOTTOM - ERASE_TOP)
    page.paste(fill, (ERASE_LEFT, ERASE_TOP), mask)
    width = ERASE_RIGHT - ERASE_LEFT
    line = page.crop((INTERIOR_SOURCE_LEFT, LINE_BAND[0], INTERIOR_SOURCE_LEFT + width, LINE_BAND[1]))
    page.paste(line, (ERASE_LEFT, LINE_BAND[0]))
    strip = page.crop(RIGHT_LINE_STRIP)
    for y in range(ERASE_TOP, LINE_BAND[0], strip.size[1]):
        tile = strip.crop((0, 0, strip.size[0], min(strip.size[1], LINE_BAND[0] - y)))
        page.paste(tile, (RIGHT_LINE_STRIP[0], y))
    return page


def distance_mask(image, paper):
    distance = Image.new("L", image.size, 0)
    pixels = image.load()
    out = distance.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            red, green, blue = pixels[x, y][:3]
            out[x, y] = 255 if abs(red - paper[0]) + abs(green - paper[1]) + abs(blue - paper[2]) > 60 else 0
    return distance


def figure_mask(image, paper):
    """The figure with its enclosed highlights: everything the flood fill from the corner does not reach."""
    distance = distance_mask(image, paper)
    ImageDraw.floodfill(distance, (0, 0), 128)
    return distance.point(lambda value: 0 if value == 128 else 255)


def place_figure(page, figure_path):
    source = Image.open(figure_path).convert("RGB").crop(FIGURE_SEARCH)
    corner = (0, 0, 40, 40)
    mask = figure_mask(source, paper_mean(source, corner))
    bbox = mask.getbbox()
    figure = source.crop(bbox)
    alpha = mask.crop(bbox).filter(ImageFilter.MaxFilter(3))
    target_height = round((FRAME[3] - FRAME[1]) * FIGURE_HEIGHT_SHARE)
    scale = target_height / figure.size[1]
    size = (round(figure.size[0] * scale), target_height)
    page.paste(figure.resize(size, Image.LANCZOS), (RIGHT_X - size[0], FEET_Y - size[1]), alpha.resize(size, Image.LANCZOS))
    return bbox, size


def main(figure_path):
    """Without a figure path the page is left empty (user, 2026-10-18: the astronaut off the template)."""
    page = match_paper(Image.open(PAGE).convert("RGB"), Image.open(ORIGINAL).convert("RGB"))
    page = erase_big_figure(page)
    if figure_path:
        bbox, size = place_figure(page, figure_path)
        print(OUT, "figure", bbox, "placed", size)
    else:
        print(OUT, "no figure")
    page.save(OUT)


if __name__ == "__main__" and (len(sys.argv) < 2 or sys.argv[1] != "layout"):
    main(sys.argv[1] if len(sys.argv) > 1 else None)


# The second layout (user, 2026-10-18): the hero frame over most of the page, the elevations and the swatches in a
# strip below. Built from the figureless page: the ink inside the erase area filled with paper, the frame redrawn
# from the old frame's line strips (the right line is the left one mirrored: the old right line was tiled by the
# figure erase and shows steps), the two groups shrunk, the title line moved up clear of the frame.
LAYOUT_SOURCE = "work/art/page-2/figureless.png"
PAPER_AREA = (125, 62, 2255, 1714)
ERASE_AREA = (200, 150, 2210, 1700)
INK_LUMINANCE = 150
INK_GROW = 11
FILL_DISTANCES = (30, 45, 60, 90, 120, 180, 240)
TITLE_LINE = (190, 170, 1140, 205)
TITLE_LINE_AT = (190, 135)
# The old frame's line centres and the new ones, x then y.
OLD_FRAME = (407.5, 241.5, 1992.0, 1127.5)
NEW_FRAME = (180, 215, 2185, 1455)
STRIP = 20
TOP_STRIP = (393, 232, 2005, 252)
BOTTOM_STRIP = (393, 1118, 2005, 1138)
LEFT_STRIP = (398, 232, 418, 1138)
ELEVATIONS_CROP = (200, 1180, 1290, 1680)
ELEVATIONS_SCALE = 0.44
ELEVATIONS_AT = (170, 1478)
SWATCHES_CROP = (1410, 1380, 2200, 1595)
SWATCHES_SCALE = 0.8
SWATCHES_AT = (1550, 1498)


def area_mask(size, area):
    mask = Image.new("L", size, 0)
    mask.paste(255, area)
    return mask


def ink_mask(page):
    """The ink inside the erase area, grown so the soft stroke edges go with it."""
    luminance = page.convert("L").point(lambda value: 255 if value < INK_LUMINANCE else 0)
    return ImageChops.multiply(luminance, area_mask(page.size, ERASE_AREA)).filter(ImageFilter.MaxFilter(INK_GROW))


def fill_from_paper(page, mask):
    """Each inked pixel takes the nearest paper along an axis, growing the reach until all is filled."""
    paper = ImageChops.subtract(area_mask(page.size, PAPER_AREA), mask)
    remaining = mask
    for distance in FILL_DISTANCES:
        for shift in ((0, -distance), (-distance, 0), (0, distance), (distance, 0)):
            usable = ImageChops.multiply(remaining, ImageChops.offset(paper, *shift))
            page.paste(ImageChops.offset(page, *shift), (0, 0), usable)
            remaining = ImageChops.subtract(remaining, usable)
    return page


def four_edge_alpha(size, ramp):
    alpha = Image.new("L", size, 255)
    pixels = alpha.load()
    for y in range(size[1]):
        for x in range(size[0]):
            distance = min(x, y, size[0] - 1 - x, size[1] - 1 - y, ramp)
            pixels[x, y] = round(255 * distance / ramp)
    return alpha


def place_scaled(page, source, crop, scale, at, ramp):
    piece = source.crop(crop)
    size = tuple(round(side * scale) for side in piece.size) if isinstance(scale, float) else scale
    page.paste(piece.resize(size, Image.LANCZOS), at, four_edge_alpha(size, ramp))
    return size


def draw_frame(page, source):
    """The old frame's line strips, stretched along their length, their line centres on NEW_FRAME."""
    scale_x = (NEW_FRAME[2] - NEW_FRAME[0]) / (OLD_FRAME[2] - OLD_FRAME[0])
    scale_y = (NEW_FRAME[3] - NEW_FRAME[1]) / (OLD_FRAME[3] - OLD_FRAME[1])
    width = round((TOP_STRIP[2] - TOP_STRIP[0]) * scale_x)
    height = round((LEFT_STRIP[3] - LEFT_STRIP[1]) * scale_y)
    left = round(NEW_FRAME[0] - (OLD_FRAME[0] - TOP_STRIP[0]) * scale_x)
    top = round(NEW_FRAME[1] - (OLD_FRAME[1] - LEFT_STRIP[1]) * scale_y)
    line_offset = (OLD_FRAME[1] - TOP_STRIP[1], OLD_FRAME[0] - LEFT_STRIP[0])
    place_scaled(page, source, TOP_STRIP, (width, STRIP), (left, round(NEW_FRAME[1] - line_offset[0])), 6)
    place_scaled(page, source, BOTTOM_STRIP, (width, STRIP), (left, round(NEW_FRAME[3] - line_offset[0])), 6)
    left_line = source.crop(LEFT_STRIP)
    place_scaled(page, source, LEFT_STRIP, (STRIP, height), (round(NEW_FRAME[0] - line_offset[1]), top), 6)
    mirrored = left_line.transpose(Image.FLIP_LEFT_RIGHT).resize((STRIP, height), Image.LANCZOS)
    right = round(NEW_FRAME[2] - (STRIP - 1 - line_offset[1]))
    page.paste(mirrored, (right, top), four_edge_alpha((STRIP, height), 6))


def layout():
    source = Image.open(LAYOUT_SOURCE).convert("RGB")
    page = fill_from_paper(source.copy(), ink_mask(source))
    place_scaled(page, source, TITLE_LINE, 1.0, TITLE_LINE_AT, 6)
    draw_frame(page, source)
    elevations_size = place_scaled(page, source, ELEVATIONS_CROP, ELEVATIONS_SCALE, ELEVATIONS_AT, 8)
    swatches_size = place_scaled(page, source, SWATCHES_CROP, SWATCHES_SCALE, SWATCHES_AT, 8)
    page.save(OUT)
    print(OUT, "layout", NEW_FRAME, elevations_size, swatches_size)


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "layout":
    layout()
