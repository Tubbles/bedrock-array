"""Image helpers shared by the material scripts: sRGB encoding and decoding, PNG writing and the seam check."""

import numpy
import OpenImageIO


def encode_srgb(linear):
    linear = numpy.clip(linear, 0, 1)
    curve = 1.055 * numpy.power(linear, 1 / 2.4) - 0.055
    return numpy.where(linear > 0.0031308, curve, 12.92 * linear)


def decode_srgb(encoded):
    curve = numpy.power((encoded + 0.055) / 1.055, 2.4)
    return numpy.where(encoded > 0.04045, curve, encoded / 12.92)


def to_bytes(values):
    top_row_first = values[::-1]
    return numpy.round(numpy.clip(top_row_first, 0, 1) * 255).astype(numpy.uint8)


def write_png(path, values, colour_space):
    pixels = numpy.ascontiguousarray(to_bytes(values))
    spec = OpenImageIO.ImageSpec(pixels.shape[1], pixels.shape[0], 3, "uint8")
    spec.attribute("oiio:ColorSpace", colour_space)
    output = OpenImageIO.ImageOutput.create(path)
    output.open(path, spec)
    output.write_image(pixels)
    output.close()


def print_seam_check(map_name, values):
    """Compare each wrap seam with the image's mean step between adjacent columns or rows."""
    left_right = numpy.abs(values[:, 0] - values[:, -1]).mean()
    top_bottom = numpy.abs(values[0] - values[-1]).mean()
    column_step = numpy.abs(numpy.diff(values, axis=1)).mean()
    row_step = numpy.abs(numpy.diff(values, axis=0)).mean()
    verdict = "ok" if left_right <= 1.5 * column_step and top_bottom <= 1.5 * row_step else "check"
    print(
        "SEAM %s left_right=%.4f top_bottom=%.4f column_step=%.4f row_step=%.4f %s"
        % (map_name, left_right, top_bottom, column_step, row_step, verdict)
    )
