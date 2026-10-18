"""Bake a material's tileable albedo, normal and surface maps from a parameter file in Blender.

Run from the repository root as `flatpak run org.blender.Blender -b --python "$PWD/tools/materials/bake.py" -- <name> [size]`;
the path is absolute because the flatpak starts in its own directory.
"""

import math
import os
import sys

import bpy
import numpy

SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIRECTORY))
TORUS_RADIUS = 1.2
sys.path.insert(0, SCRIPT_DIRECTORY)

import sjson  # noqa: E402
from images import encode_srgb, print_seam_check, write_png  # noqa: E402


# Parameters


def read_arguments():
    arguments = sys.argv[sys.argv.index("--") + 1 :]
    size = int(arguments[1]) if len(arguments) > 1 else 512
    return arguments[0], size


def read_parameters(name):
    path = os.path.join(REPOSITORY_ROOT, "data", "materials", "bake", name + ".sjson")
    with open(path, encoding="utf-8") as file:
        return sjson.parse(file.read())


# Scene


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1


def create_bake_plane():
    bpy.ops.mesh.primitive_plane_add(size=2)
    plane = bpy.context.active_object
    material = bpy.data.materials.new("bake")
    plane.data.materials.append(material)
    for node in list(material.node_tree.nodes):
        material.node_tree.nodes.remove(node)
    return material.node_tree


def create_output(tree):
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    emission = tree.nodes.new("ShaderNodeEmission")
    tree.links.new(emission.outputs[0], output.inputs[0])
    texture = tree.nodes.new("ShaderNodeTexImage")
    tree.nodes.active = texture
    return emission, texture


# Nodes


def connect_or_set(tree, socket, value):
    if isinstance(value, (int, float)):
        socket.default_value = value
    else:
        tree.links.new(value, socket)


def math_node(tree, operation, first, second=None):
    node = tree.nodes.new("ShaderNodeMath")
    node.operation = operation
    connect_or_set(tree, node.inputs[0], first)
    if second is not None:
        connect_or_set(tree, node.inputs[1], second)
    return node.outputs[0]


def circle(tree, coordinate):
    angle = math_node(tree, "MULTIPLY", coordinate, 2 * math.pi)
    cosine = math_node(tree, "MULTIPLY", math_node(tree, "COSINE", angle), TORUS_RADIUS)
    sine = math_node(tree, "MULTIPLY", math_node(tree, "SINE", angle), TORUS_RADIUS)
    return cosine, sine


def torus_coordinate(tree, seed):
    """The UV mapped onto a torus in 4D, as (Vector, W) sockets, so every channel tiles."""
    texture_coordinate = tree.nodes.new("ShaderNodeTexCoord")
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    tree.links.new(texture_coordinate.outputs["UV"], separate.inputs[0])
    cosine_u, sine_u = circle(tree, separate.outputs[0])
    cosine_v, sine_v = circle(tree, separate.outputs[1])
    combine = tree.nodes.new("ShaderNodeCombineXYZ")
    for index, socket in enumerate((cosine_u, sine_u, cosine_v)):
        tree.links.new(socket, combine.inputs[index])
    return combine.outputs[0], math_node(tree, "ADD", sine_v, float(seed))


def noise_4d(tree, coordinate, scale, detail):
    node = tree.nodes.new("ShaderNodeTexNoise")
    node.noise_dimensions = "4D"
    tree.links.new(coordinate[0], node.inputs["Vector"])
    tree.links.new(coordinate[1], node.inputs["W"])
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    return node.outputs["Fac"]


def voronoi_4d(tree, coordinate, scale):
    node = tree.nodes.new("ShaderNodeTexVoronoi")
    node.voronoi_dimensions = "4D"
    node.feature = "F1"
    tree.links.new(coordinate[0], node.inputs["Vector"])
    tree.links.new(coordinate[1], node.inputs["W"])
    node.inputs["Scale"].default_value = scale
    return node.outputs["Distance"]


def mix_float(tree, first, second, blend):
    difference = math_node(tree, "SUBTRACT", second, first)
    return math_node(tree, "ADD", first, math_node(tree, "MULTIPLY", difference, blend))


# Channels


def mottle_channel(tree, coordinate, parameters):
    return noise_4d(tree, coordinate, parameters["paint"]["mottle_scale"], 4)


def orange_peel_channel(tree, coordinate, parameters):
    return noise_4d(tree, coordinate, parameters["paint"]["orange_peel_scale"], 2)


def steel_noise_channel(tree, coordinate, parameters):
    return noise_4d(tree, coordinate, parameters["steel"]["scale"], 3)


def wear_field_channel(tree, coordinate, parameters):
    wear = parameters["wear_field"]
    distance = voronoi_4d(tree, coordinate, wear["voronoi_scale"])
    cell_centres = math_node(tree, "SUBTRACT", 1.0, distance)
    noise = noise_4d(tree, coordinate, wear["noise_scale"], 2)
    return mix_float(tree, cell_centres, noise, wear["blend"])


# Bake


def bake_channel(tree, emission, texture, socket, size):
    """Bake one socket through the emission colour into a fresh float image, bottom row first."""
    tree.links.new(socket, emission.inputs["Color"])
    image = bpy.data.images.new("bake", size, size, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    texture.image = image
    bpy.ops.object.bake(type="EMIT", margin=0)
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(size, size, 4)
    return pixels[..., 0].astype(numpy.float64)


# Assembly


def albedo_map(channels, parameters):
    grey = 1 - parameters["paint"]["mottle_amount"] * channels["mottle"]
    return numpy.stack([grey, grey, grey], axis=-1)


def central_slope(height, axis, texel_metres):
    forward = numpy.roll(height, -1, axis=axis)
    backward = numpy.roll(height, 1, axis=axis)
    return (forward - backward) / (2 * texel_metres)


def normal_map(channels, parameters, size):
    paint = parameters["paint"]
    height = paint["orange_peel_height"] * (channels["orange_peel"] - 0.5)
    texel_metres = parameters["tile_metres"] / size
    slope_u = central_slope(height, 1, texel_metres)
    slope_v = central_slope(height, 0, texel_metres)
    normal = numpy.stack([-slope_u, -slope_v, numpy.ones_like(height)], axis=-1)
    normal /= numpy.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def stretch(values):
    return (values - values.min()) / (values.max() - values.min())


def surface_map(channels, parameters):
    paint, steel = parameters["paint"], parameters["steel"]
    red = paint["roughness"] + paint["roughness_variation"] * (channels["mottle"] - 0.5) * 2
    green = steel["roughness"] + steel["roughness_variation"] * (channels["steel_noise"] - 0.5) * 2
    blue = stretch(channels["wear_field"])
    return numpy.clip(numpy.stack([red, green, blue], axis=-1), 0, 1)


# Main

CHANNELS = {
    "mottle": mottle_channel,
    "orange_peel": orange_peel_channel,
    "steel_noise": steel_noise_channel,
    "wear_field": wear_field_channel,
}


def bake_channels(parameters, size):
    reset_scene()
    tree = create_bake_plane()
    emission, texture = create_output(tree)
    coordinate = torus_coordinate(tree, parameters["seed"])
    sockets = {name: build(tree, coordinate, parameters) for name, build in CHANNELS.items()}
    return {name: bake_channel(tree, emission, texture, socket, size) for name, socket in sockets.items()}


def main():
    name, size = read_arguments()
    parameters = read_parameters(name)
    channels = bake_channels(parameters, size)
    maps = {
        "albedo": albedo_map(channels, parameters),
        "normal": normal_map(channels, parameters, size),
        "surface": surface_map(channels, parameters),
    }
    directory = os.path.join(REPOSITORY_ROOT, "data", "materials", "textures")
    for map_name, values in maps.items():
        print_seam_check(map_name, values)
        path = os.path.join(directory, "%s_%s.png" % (name, map_name))
        if map_name == "albedo":
            write_png(path, encode_srgb(values), "sRGB")
        else:
            write_png(path, values, "linear")


main()
