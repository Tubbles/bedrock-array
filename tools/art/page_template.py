"""Compose the art book page template, data/art/page.png (doc/workflows/art_book.md, step 0): the pass 3 page under work/art/page-2/ with its too large figure erased and its paper tone matched to the first template, plus the figure of data/art/figure.png cut out and placed at 40 percent of the frame height. A one off with the coordinates of that page, kept so the template can be remade: python3 tools/art/page_template.py data/art/figure.png"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageStat

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
    page = match_paper(Image.open(PAGE).convert("RGB"), Image.open(ORIGINAL).convert("RGB"))
    page = erase_big_figure(page)
    bbox, size = place_figure(page, figure_path)
    page.save(OUT)
    print(OUT, "figure", bbox, "placed", size)


main(sys.argv[1])
