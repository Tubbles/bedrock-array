#!/usr/bin/env python3
"""Turn a GLB into the engine's flat mesh blob (doc/workflows/models.md).

    tools/models/mesh_blob.py <glb> <out.mesh> [--height <metres> | --keep-frame]

Gathers every root node's mesh with its translation, rotation and scale applied, moves the bounding box's
bottom centre to the origin and, with --height, scales the mesh to that height. --keep-frame writes the
positions as they are, for a mesh already in the brief's frame. The blob: the magic
BAMESH01, u32 vertex count, u32 index count, per vertex six little endian f32 (position then normal),
then the indices as u32.
"""
import argparse
import json
import struct
import sys

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BINARY = 0x004E4942
BLOB_MAGIC = b"BAMESH01"
COMPONENT_FORMATS = {5126: "f", 5125: "I", 5123: "H"}
TYPE_WIDTHS = {"SCALAR": 1, "VEC3": 3}


def read_glb(data):
    """Return the GLB's JSON document and its binary chunk."""
    magic, _version, _length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        sys.exit("not a GLB file")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != CHUNK_JSON:
        sys.exit("the first GLB chunk is not JSON")
    document = json.loads(data[20:20 + json_length])
    binary_offset = 20 + json_length
    binary_length, binary_type = struct.unpack_from("<II", data, binary_offset)
    if binary_type != CHUNK_BINARY:
        sys.exit("the second GLB chunk is not BIN")
    return document, data[binary_offset + 8:binary_offset + 8 + binary_length]


def read_accessor(document, binary, accessor_index):
    """Return an accessor's elements as tuples, honouring byteOffset and byteStride."""
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    element_format = "<" + COMPONENT_FORMATS[accessor["componentType"]] * TYPE_WIDTHS[accessor["type"]]
    element_size = struct.calcsize(element_format)
    stride = view.get("byteStride", element_size)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    if stride == element_size:
        end = start + element_size * accessor["count"]
        return list(struct.iter_unpack(element_format, binary[start:end]))
    return [struct.unpack_from(element_format, binary, start + stride * index) for index in range(accessor["count"])]


def rotate(quaternion, vector):
    """Rotate a vector by a unit quaternion [x, y, z, w]."""
    qx, qy, qz, qw = quaternion
    vx, vy, vz = vector
    tx, ty, tz = 2 * (qy * vz - qz * vy), 2 * (qz * vx - qx * vz), 2 * (qx * vy - qy * vx)
    return (vx + qw * tx + qy * tz - qz * ty, vy + qw * ty + qz * tx - qx * tz, vz + qw * tz + qx * ty - qy * tx)


def node_transform(node):
    """Return the node's translation, rotation and scale; a matrix is an error."""
    if "matrix" in node:
        sys.exit("node {!r} carries a matrix, which this tool does not take".format(node.get("name")))
    return node.get("translation", [0, 0, 0]), node.get("rotation", [0, 0, 0, 1]), node.get("scale", [1, 1, 1])


def transform_point(transform, point):
    """Scale, rotate, then translate a point."""
    translation, rotation, scale = transform
    rotated = rotate(rotation, (point[0] * scale[0], point[1] * scale[1], point[2] * scale[2]))
    return (rotated[0] + translation[0], rotated[1] + translation[1], rotated[2] + translation[2])


def root_nodes(document):
    """Return the nodes that are no other node's child."""
    children = {child for node in document["nodes"] for child in node.get("children", [])}
    return [node for index, node in enumerate(document["nodes"]) if index not in children]


def fail(message):
    """Exit with the message and status 1."""
    sys.exit(message)


def check_primitive(document, node_name, primitive):
    """Fail unless the primitive has positions, normals and indices of supported types and equal counts."""
    attributes = primitive["attributes"]
    for key in ("POSITION", "NORMAL"):
        if key not in attributes:
            fail("node {!r}: a primitive without {}".format(node_name, key))
    if "indices" not in primitive:
        fail("node {!r}: a primitive without indices".format(node_name))
    accessors = [document["accessors"][index] for index in (attributes["POSITION"], attributes["NORMAL"], primitive["indices"])]
    for accessor in accessors:
        if accessor["componentType"] not in COMPONENT_FORMATS or accessor["type"] not in TYPE_WIDTHS:
            fail("node {!r}: unsupported accessor component type {} of type {}".format(node_name, accessor["componentType"], accessor["type"]))
    if accessors[0]["count"] != accessors[1]["count"]:
        fail("node {!r}: {} positions but {} normals".format(node_name, accessors[0]["count"], accessors[1]["count"]))


def check_indices(node_name, indices, vertex_count):
    """Fail on the first index at or past the primitive's vertex count."""
    for index in indices:
        if index >= vertex_count:
            fail("node {!r}: index {} at or past the vertex count {}".format(node_name, index, vertex_count))


def gather_meshes(document, binary):
    """Return one vertex list of (position, normal) and one index list over every root node's mesh."""
    vertices, indices = [], []
    for node in root_nodes(document):
        if "mesh" not in node:
            continue
        transform = node_transform(node)
        for primitive in document["meshes"][node["mesh"]]["primitives"]:
            check_primitive(document, node.get("name"), primitive)
            positions = read_accessor(document, binary, primitive["attributes"]["POSITION"])
            normals = read_accessor(document, binary, primitive["attributes"]["NORMAL"])
            primitive_indices = [index for (index,) in read_accessor(document, binary, primitive["indices"])]
            check_indices(node.get("name"), primitive_indices, len(positions))
            offset = len(vertices)
            indices.extend(offset + index for index in primitive_indices)
            vertices.extend((transform_point(transform, position), rotate(transform[1], normal)) for position, normal in zip(positions, normals))
    return vertices, indices


def bounds(vertices):
    """Return the minimum and maximum corners of the positions."""
    columns = list(zip(*(position for position, _normal in vertices)))
    return [min(column) for column in columns], [max(column) for column in columns]


def ground_and_scale(vertices, height):
    """Move the bounding box's bottom centre to the origin and, with a height, scale to it."""
    low, high = bounds(vertices)
    centre = ((low[0] + high[0]) / 2, low[1], (low[2] + high[2]) / 2)
    if height and high[1] == low[1]:
        fail("--height on a mesh of zero height")
    factor = height / (high[1] - low[1]) if height else 1.0
    return [(tuple((position[axis] - centre[axis]) * factor for axis in range(3)), normal) for position, normal in vertices]


def write_blob(path, vertices, indices):
    """Write the header, the interleaved vertices and the u32 indices."""
    floats = [value for position, normal in vertices for value in (*position, *normal)]
    with open(path, "wb") as output:
        output.write(BLOB_MAGIC + struct.pack("<II", len(vertices), len(indices)))
        output.write(struct.pack("<{}f".format(len(floats)), *floats))
        output.write(struct.pack("<{}I".format(len(indices)), *indices))


def main():
    parser = argparse.ArgumentParser(description="Turn a GLB into the engine's flat mesh blob.")
    parser.add_argument("glb")
    parser.add_argument("out")
    placement = parser.add_mutually_exclusive_group()
    placement.add_argument("--height", type=float, help="scale the mesh to this height in metres")
    placement.add_argument("--keep-frame", action="store_true", help="write the positions as they are, without the grounding")
    arguments = parser.parse_args()
    with open(arguments.glb, "rb") as source:
        document, binary = read_glb(source.read())
    vertices, indices = gather_meshes(document, binary)
    if not arguments.keep_frame:
        vertices = ground_and_scale(vertices, arguments.height)
    write_blob(arguments.out, vertices, indices)
    low, high = bounds(vertices)
    print("{}: {} vertices, {} indices, bounds [{:.4f} {:.4f} {:.4f}] to [{:.4f} {:.4f} {:.4f}]".format(arguments.out, len(vertices), len(indices), *low, *high))


if __name__ == "__main__":
    main()
