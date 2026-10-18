"""Render a baked material set on bevelled boxes with the wear rule, lay out its maps tiled and print the checks.

Run from the repository root as `flatpak run org.blender.Blender -b --python "$PWD/tools/materials/review.py" -- <name>`.
"""

import math
import os
import sys
import tempfile

import bpy
import numpy
import OpenImageIO

SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIRECTORY))
FAR_SCALE_FACTOR = 2.71828
MAP_NAMES = ("albedo", "normal", "surface")
sys.path.insert(0, SCRIPT_DIRECTORY)

import sjson  # noqa: E402
from images import decode_srgb, encode_srgb, print_seam_check, write_png  # noqa: E402


# Reading


def read_sjson(*parts):
    with open(os.path.join(REPOSITORY_ROOT, *parts), encoding="utf-8") as file:
        return sjson.parse(file.read())


def map_path(name, map_name):
    return os.path.join(REPOSITORY_ROOT, "data", "materials", "textures", "%s_%s.png" % (name, map_name))


def read_png(path):
    """The image as floats 0 to 1, top row first, RGB."""
    image = OpenImageIO.ImageInput.open(path)
    pixels = image.read_image("float")
    image.close()
    return numpy.asarray(pixels, dtype=numpy.float64)[..., :3]


def read_inputs(name):
    maps = {map_name: read_png(map_path(name, map_name)) for map_name in MAP_NAMES}
    preset = read_sjson("data", "materials", "library.sjson")[name]
    tile_metres = read_sjson("data", "materials", "bake", name + ".sjson")["tile_metres"]
    return maps, preset, tile_metres


# Scene


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    # The game tone maps with an ACES fit and the sheet with AgX, so the sheet is a look, not a match.
    scene.view_settings.view_transform = "AgX"
    return scene


def add_box(location, material):
    bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    box = bpy.context.active_object
    bevel = box.modifiers.new("bevel", "BEVEL")
    bevel.width = 0.02
    bevel.segments = 3
    box.data.materials.append(material)


def sun_azimuth(sun):
    """The sky's sun rotation for the lamp: clockwise from +Y, the direction the light comes from."""
    towards_light = sun.matrix_world.to_3x3().col[2]
    return math.atan2(towards_light.x, towards_light.y)


def add_sky(scene, sun):
    """A single scattering sky, so the bare metal has something to reflect."""
    scene.world = bpy.data.worlds.new("world")
    tree = scene.world.node_tree
    sky = tree.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "SINGLE_SCATTERING"
    sky.sun_elevation = math.radians(25)
    sky.sun_rotation = sun_azimuth(sun)
    sky.sun_intensity = 0.3
    background = tree.nodes["Background"]
    background.inputs["Strength"].default_value = 0.03
    tree.links.new(sky.outputs[0], background.inputs["Color"])


def add_ground():
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1))
    material = bpy.data.materials.new("ground")
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (0.16, 0.12, 0.08, 1)
    shader.inputs["Roughness"].default_value = 0.9
    bpy.context.active_object.data.materials.append(material)


def add_light_camera_world(scene):
    bpy.ops.object.light_add(type="SUN", rotation=(0.8, 0.2, 0.6))
    sun = bpy.context.active_object
    sun.data.energy = 3
    bpy.context.view_layer.update()
    bpy.ops.object.camera_add(location=(4, -4, 3.2), rotation=(1.1, 0, 0.785))
    scene.camera = bpy.context.active_object
    add_sky(scene, sun)


# Nodes


def connect_or_set(tree, socket, value):
    if isinstance(value, bpy.types.NodeSocket):
        tree.links.new(value, socket)
    else:
        socket.default_value = value


def math_node(tree, operation, first, second=None):
    node = tree.nodes.new("ShaderNodeMath")
    node.operation = operation
    connect_or_set(tree, node.inputs[0], first)
    if second is not None:
        connect_or_set(tree, node.inputs[1], second)
    return node.outputs[0]


def scale_vector(tree, vector, factor):
    node = tree.nodes.new("ShaderNodeVectorMath")
    node.operation = "SCALE"
    tree.links.new(vector, node.inputs[0])
    node.inputs["Scale"].default_value = factor
    return node.outputs[0]


def mix_node(tree, data_type, factor, first, second, blend_type="MIX"):
    """A Mix node; its float sockets are inputs 2 and 3, its colour sockets 6 and 7."""
    node = tree.nodes.new("ShaderNodeMix")
    node.data_type = data_type
    node.blend_type = blend_type
    offset = 2 if data_type == "FLOAT" else 6
    connect_or_set(tree, node.inputs[0], factor)
    connect_or_set(tree, node.inputs[offset], first)
    connect_or_set(tree, node.inputs[offset + 1], second)
    return node.outputs[0 if data_type == "FLOAT" else 2]


def separate_xyz(tree, vector):
    node = tree.nodes.new("ShaderNodeSeparateXYZ")
    tree.links.new(vector, node.inputs[0])
    return node.outputs[0], node.outputs[1], node.outputs[2]


# Material groups


def coordinate_nodes(tree, tile_metres):
    """The object coordinate, the near scale and the far scale.

    The game swizzles the far coordinate zxy; Blender's box projection picks the
    face from the normal, so a swizzled vector degenerates to a streak there, and
    the far scale is only scaled.
    """
    object_coordinate = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    near = scale_vector(tree, object_coordinate, 1 / tile_metres)
    far = scale_vector(tree, object_coordinate, 1 / (tile_metres * FAR_SCALE_FACTOR))
    return object_coordinate, near, far


def image_texture(tree, image, vector):
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    node.projection = "BOX"
    node.projection_blend = 0.2
    tree.links.new(vector, node.inputs["Vector"])
    return node.outputs["Color"]


def load_image(name, map_name):
    image = bpy.data.images.load(map_path(name, map_name))
    image.colorspace_settings.name = "sRGB" if map_name == "albedo" else "Non-Color"
    return image


def map_nodes(tree, name, near, far):
    """The albedo and surface maps mixed half and half over both scales, the normal at the near scale."""
    images = {map_name: load_image(name, map_name) for map_name in MAP_NAMES}
    albedo = mix_node(tree, "RGBA", 0.5, image_texture(tree, images["albedo"], near), image_texture(tree, images["albedo"], far))
    surface = mix_node(tree, "RGBA", 0.5, image_texture(tree, images["surface"], near), image_texture(tree, images["surface"], far))
    # The tangent space Normal Map node over a box projected texture approximates the game's triplanar normal.
    normal_map = tree.nodes.new("ShaderNodeNormalMap")
    normal_map.space = "TANGENT"
    tree.links.new(image_texture(tree, images["normal"], near), normal_map.inputs["Color"])
    separate = tree.nodes.new("ShaderNodeSeparateColor")
    tree.links.new(surface, separate.inputs[0])
    return albedo, normal_map.outputs[0], separate.outputs


def edge_distance(tree, object_coordinate):
    """The second smallest of 1 - |coordinate| per axis: the distance to the box's nearest edge."""
    x, y, z = (math_node(tree, "SUBTRACT", 1.0, math_node(tree, "ABSOLUTE", axis)) for axis in separate_xyz(tree, object_coordinate))
    pairs = (math_node(tree, "MINIMUM", x, y), math_node(tree, "MINIMUM", x, z), math_node(tree, "MINIMUM", y, z))
    return math_node(tree, "MAXIMUM", math_node(tree, "MAXIMUM", pairs[0], pairs[1]), pairs[2])


def wear_nodes(tree, object_coordinate, field, wear):
    """wear = (field + amount * (1 - smoothstep(0, edge_width, edge))) > chip_threshold, as in doc/workflows/materials.md."""
    smoothstep = tree.nodes.new("ShaderNodeMapRange")
    smoothstep.interpolation_type = "SMOOTHSTEP"
    tree.links.new(edge_distance(tree, object_coordinate), smoothstep.inputs["Value"])
    smoothstep.inputs["From Min"].default_value = 0.0
    smoothstep.inputs["From Max"].default_value = wear["edge_width"]
    near_edge = math_node(tree, "SUBTRACT", 1.0, smoothstep.outputs["Result"])
    lifted = math_node(tree, "ADD", field, math_node(tree, "MULTIPLY", near_edge, wear["amount"]))
    return math_node(tree, "GREATER_THAN", lifted, wear["chip_threshold"])


def shader_nodes(tree, preset, albedo, normal, surface, wear):
    paint = mix_node(tree, "RGBA", 1.0, albedo, (*preset["albedo"], 1.0), "MULTIPLY")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(mix_node(tree, "RGBA", wear, paint, (*preset["wear"]["metal"], 1.0)), shader.inputs["Base Color"])
    tree.links.new(mix_node(tree, "FLOAT", wear, surface[0], surface[1]), shader.inputs["Roughness"])
    tree.links.new(wear, shader.inputs["Metallic"])
    tree.links.new(normal, shader.inputs["Normal"])
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    tree.links.new(shader.outputs[0], output.inputs["Surface"])


def build_material(name, preset, tile_metres):
    material = bpy.data.materials.new(name)
    tree = material.node_tree
    for node in list(tree.nodes):
        tree.nodes.remove(node)
    object_coordinate, near, far = coordinate_nodes(tree, tile_metres)
    albedo, normal, surface = map_nodes(tree, name, near, far)
    wear = wear_nodes(tree, object_coordinate, surface[2], preset["wear"])
    shader_nodes(tree, preset, albedo, normal, surface, wear)
    return material


# Render


def render(name, preset, tile_metres):
    """The scene rendered to a temporary PNG and read back, top row first."""
    scene = reset_scene()
    material = build_material(name, preset, tile_metres)
    add_box((0, 0, 0), material)
    add_box((-2, 7, 0), material)
    add_ground()
    add_light_camera_world(scene)
    with tempfile.TemporaryDirectory() as directory:
        scene.render.filepath = os.path.join(directory, "render.png")
        bpy.ops.render.render(write_still=True)
        return read_png(scene.render.filepath)


# Sheet


def box_downsample(values, size):
    factor = values.shape[0] // size
    return values.reshape(size, factor, size, factor, 3).mean(axis=(1, 3))


def tiled_panel(values, repeats):
    tile = box_downsample(values, 256 // repeats)
    return numpy.tile(tile, (repeats, repeats, 1))


def stretch_contrast(panel):
    """The panel's range stretched to 0 to 1, so the near white albedo's mottle shows."""
    return (panel - panel.min()) / (panel.max() - panel.min())


def panel_row(maps):
    panels = [tiled_panel(maps[map_name], 2) for map_name in MAP_NAMES]
    panels[0] = stretch_contrast(panels[0])
    panels.append(stretch_contrast(tiled_panel(maps["albedo"], 8)))
    return numpy.concatenate(panels, axis=1)


def write_sheet(name, rendered, maps):
    sheet = numpy.concatenate([rendered, panel_row(maps)], axis=0)
    directory = os.path.join(REPOSITORY_ROOT, "work", "materials")
    os.makedirs(directory, exist_ok=True)
    # write_png takes the bake's bottom row first order.
    write_png(os.path.join(directory, name + "_review.png"), sheet[::-1], "sRGB")


# Checks


def verdict(passed):
    return "ok" if passed else "check"


def print_repeat_check(albedo):
    """The normalised autocorrelation of the albedo's grey, its peak outside a 16 texel radius of zero."""
    grey = decode_srgb(albedo).mean(axis=-1)
    spectrum = numpy.fft.fft2(grey - grey.mean())
    correlation = numpy.fft.ifft2(numpy.abs(spectrum) ** 2).real
    correlation /= correlation[0, 0]
    size = grey.shape[0]
    offsets = numpy.minimum(numpy.arange(size), size - numpy.arange(size))
    distance = numpy.hypot(offsets[:, None], offsets[None, :])
    peak = correlation[distance > 16].max()
    print("REPEAT albedo peak=%.3f %s" % (peak, verdict(peak < 0.5)))


def print_albedo_range_check(albedo, preset):
    tinted = numpy.round(encode_srgb(decode_srgb(albedo) * preset["albedo"]) * 255)
    low, high = int(tinted.min()), int(tinted.max())
    print("RANGE albedo min=%d max=%d %s" % (low, high, verdict(low >= 30 and high <= 240)))


def print_roughness_range_check(surface):
    low, high = surface[..., :2].min(), surface[..., :2].max()
    print("RANGE roughness min=%.3f max=%.3f %s" % (low, high, verdict(low >= 0.05 and high <= 0.95)))


def print_wear_check(surface, wear):
    """The share of a face away from the edges that chips: the field is read at two
    scales and averaged, which a roll of the map against itself stands in for."""
    field = surface[..., 2]
    size = field.shape[0]
    mixed = (field + numpy.roll(field, (size // 2, size // 3), axis=(0, 1))) / 2
    coverage = (mixed > wear["chip_threshold"]).mean()
    print("WEAR coverage=%.3f %s" % (coverage, verdict(0.005 <= coverage <= 0.2)))


def print_checks(maps, preset):
    for map_name in MAP_NAMES:
        print_seam_check(map_name, maps[map_name])
    print_repeat_check(maps["albedo"])
    print_albedo_range_check(maps["albedo"], preset)
    print_roughness_range_check(maps["surface"])
    print_wear_check(maps["surface"], preset["wear"])


# Main


def main():
    name = sys.argv[sys.argv.index("--") + 1]
    maps, preset, tile_metres = read_inputs(name)
    write_sheet(name, render(name, preset, tile_metres), maps)
    print_checks(maps, preset)


if __name__ == "__main__":
    main()
