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


def mix_float(tree, first, second, blend):
    difference = math_node(tree, "SUBTRACT", second, first)
    return math_node(tree, "ADD", first, math_node(tree, "MULTIPLY", difference, blend))


# Fields


def voronoi_cells_4d(tree, coordinate, scale):
    """The F1 distance and a per cell random value from 0 to 1."""
    node = tree.nodes.new("ShaderNodeTexVoronoi")
    node.voronoi_dimensions = "4D"
    node.feature = "F1"
    node.distance = "EUCLIDEAN"
    tree.links.new(coordinate[0], node.inputs["Vector"])
    tree.links.new(coordinate[1], node.inputs["W"])
    node.inputs["Scale"].default_value = scale
    separate = tree.nodes.new("ShaderNodeSeparateColor")
    tree.links.new(node.outputs["Color"], separate.inputs[0])
    return node.outputs["Distance"], separate.outputs["Red"]


def smoothstep(tree, value, low, high):
    node = tree.nodes.new("ShaderNodeMapRange")
    node.interpolation_type = "SMOOTHSTEP"
    node.clamp = True
    tree.links.new(value, node.inputs["Value"])
    node.inputs["From Min"].default_value = low
    node.inputs["From Max"].default_value = high
    return node.outputs["Result"]


def noise_layer(tree, coordinate, layer):
    return noise_4d(tree, coordinate, layer["scale"], layer["detail"])


def blobs_layer(tree, coordinate, layer):
    """Blobs of 1 at each cell's point falling to 0 at a per cell radius, so blobs vary in size."""
    distance, random = voronoi_cells_4d(tree, coordinate, layer["scale"])
    radius, variation = layer["radius"], layer["radius_variation"]
    radius_cell = math_node(tree, "ADD", math_node(tree, "MULTIPLY", random, variation * radius), (1 - variation) * radius)
    blob = math_node(tree, "SUBTRACT", 1.0, math_node(tree, "DIVIDE", distance, radius_cell))
    blob.node.use_clamp = True
    return blob


def combine_max(tree, value, layer_socket, layer):
    return math_node(tree, "MAXIMUM", value, layer_socket)


def combine_add(tree, value, layer_socket, layer):
    return math_node(tree, "ADD", value, math_node(tree, "MULTIPLY", layer_socket, layer.get("amount", 1)))


def combine_multiply(tree, value, layer_socket, layer):
    return math_node(tree, "MULTIPLY", value, layer_socket)


def combine_mix(tree, value, layer_socket, layer):
    return mix_float(tree, value, layer_socket, layer["amount"])


def combine_gate(tree, value, layer_socket, layer):
    gate = smoothstep(tree, layer_socket, layer["low"], layer["high"])
    amount = layer["amount"]
    factor = math_node(tree, "ADD", math_node(tree, "MULTIPLY", gate, amount), 1.0 - amount)
    return math_node(tree, "MULTIPLY", value, factor)


# Per kind: the procedure and its keys. Per combine: the procedure, its required keys and its optional keys.
KINDS = {
    "noise": (noise_layer, {"scale", "detail"}),
    "blobs": (blobs_layer, {"scale", "radius", "radius_variation"}),
}
COMBINES = {
    "max": (combine_max, set(), set()),
    "add": (combine_add, set(), {"amount"}),
    "multiply": (combine_multiply, set(), set()),
    "mix": (combine_mix, {"amount"}, set()),
    "gate": (combine_gate, {"low", "high", "amount"}, set()),
}


def check_layer(field, index, layer):
    """Raise on an unknown kind, combine or key, or a missing key."""
    where = "field %s layer %d" % (field, index)
    if layer.get("kind") not in KINDS:
        raise ValueError("%s: unknown kind %r" % (where, layer.get("kind")))
    combine = layer.get("combine", "max")
    if combine not in COMBINES:
        raise ValueError("%s: unknown combine %r" % (where, combine))
    required = KINDS[layer["kind"]][1] | COMBINES[combine][1] | {"kind"}
    allowed = required | COMBINES[combine][2] | {"combine"}
    if required - set(layer):
        raise ValueError("%s: missing keys %s" % (where, sorted(required - set(layer))))
    if set(layer) - allowed:
        raise ValueError("%s: unknown keys %s" % (where, sorted(set(layer) - allowed)))


def layer_value(tree, coordinate, layer):
    return KINDS[layer["kind"]][0](tree, coordinate, layer)


def combine_layer(tree, value, layer_socket, layer):
    return COMBINES[layer.get("combine", "max")][0](tree, value, layer_socket, layer)


def is_identity_on_zero(layer):
    """A max, or an add of amount 1, against the zero start is the layer itself."""
    combine = layer.get("combine", "max")
    return combine == "max" or (combine == "add" and layer.get("amount", 1) == 1)


def field_stack(tree, coordinate, field, layers):
    """A field's value: the layers joined in order onto a value that starts at 0."""
    if not layers:
        raise ValueError("field %s: empty stack" % field)
    value = 0.0
    for index, layer in enumerate(layers):
        check_layer(field, index, layer)
        layer_socket = layer_value(tree, coordinate, layer)
        if index == 0 and is_identity_on_zero(layer):
            value = layer_socket
        else:
            value = combine_layer(tree, value, layer_socket, layer)
    return value


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
    green = steel["roughness"] + steel["roughness_variation"] * (channels["steel_grain"] - 0.5) * 2
    blue = stretch(channels["wear"])
    return numpy.clip(numpy.stack([red, green, blue], axis=-1), 0, 1)


# Main


# The fields the assembly reads; a parameter file names exactly these.
FIELD_NAMES = ("mottle", "orange_peel", "steel_grain", "wear")


def check_field_names(fields):
    names = set(fields)
    if names != set(FIELD_NAMES):
        raise ValueError("fields: expected %s, found %s" % (sorted(FIELD_NAMES), sorted(names)))


def bake_channels(parameters, size):
    check_field_names(parameters["fields"])
    reset_scene()
    tree = create_bake_plane()
    emission, texture = create_output(tree)
    coordinate = torus_coordinate(tree, parameters["seed"])
    sockets = {name: field_stack(tree, coordinate, name, layers) for name, layers in parameters["fields"].items()}
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
