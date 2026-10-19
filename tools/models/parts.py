#!/usr/bin/env python3
"""Map a generated model's parts onto its brief's parts and write one mesh blob per brief part (doc/workflows/models.md, the finish step).

    python3 -I tools/models/parts.py <machine> [--ply-directory <dir>]

Reads data/machines/<machine>/brief.sjson and generated.sjson, gathers each root node's mesh, moves the
whole model's bounding box bottom centre to the origin, scales it to the brief's height and turns the
generated front to the brief's +z. Each generated part goes to its override, else to the brief part with
the largest share of its vertices inside one of that part's blockout boxes grown by the margin (equal
shares to the smaller blockout), else to the brief part with the box centre nearest its bounding box
centre. Writes data/demos/parts/meshes/<brief part>.mesh in the brief's frame and prints one line per
generated part. With --ply-directory each brief part's merged mesh is also written there as <brief part>.ply,
for the closing by reconstruct.py.
"""
import argparse
import math
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "materials"))
sys.path.insert(0, os.path.join(ROOT, "tools", "models"))

import mesh_blob  # noqa: E402
import sjson  # noqa: E402

OUTPUT_DIRECTORY = os.path.join(ROOT, "data", "demos", "parts", "meshes")
TURNS = {
    "+z": lambda x, y, z: (x, y, z),
    "+x": lambda x, y, z: (-z, y, x),
    "-x": lambda x, y, z: (z, y, -x),
    "-z": lambda x, y, z: (-x, y, -z),
}


def read_sjson(path):
    """Return the parsed SJSON file."""
    with open(path) as source:
        return sjson.parse(source.read())


def turn(front, vector):
    """Turn a vector by the quarter turns that bring the front axis to +z."""
    return TURNS[front](*vector)


def blockout_boxes(brief_part):
    """Return the brief part's blockout shapes as (position, size) pairs."""
    blockout = brief_part["blockout"]
    shapes = blockout if isinstance(blockout, list) else [blockout]
    return [(shape["position"], shape["size"]) for shape in shapes]


def inside_box(point, box, margin):
    """Whether the point lies inside the axis aligned box grown by the margin."""
    position, size = box
    return all(abs(point[axis] - position[axis]) <= size[axis] / 2 + margin for axis in range(3))


def share_inside(positions, boxes, margin):
    """Return the share of the positions inside any of the boxes grown by the margin."""
    count = sum(1 for point in positions if any(inside_box(point, box, margin) for box in boxes))
    return count / len(positions) if positions else 0.0


def bounds_centre(positions):
    """Return the centre of the positions' bounding box."""
    columns = list(zip(*positions))
    return tuple((min(column) + max(column)) / 2 for column in columns)


def nearest_box_distance(point, boxes):
    """Return the distance from the point to the nearest box centre."""
    return min(math.dist(point, position) for position, _size in boxes)


def blockout_volume(boxes):
    """Return the summed volume of the boxes."""
    return sum(size[0] * size[1] * size[2] for _position, size in boxes)


def assign(part_name, overrides, brief_names, shares, distances, volumes):
    """Return the brief part name for a generated part and how it was chosen: override, share or nearest.

    Equal shares go to the brief part of the smaller blockout volume, the more specific one.
    """
    if part_name in overrides:
        return overrides[part_name], "override"
    best = max(range(len(brief_names)), key=lambda index: (shares[index], -volumes[index]))
    if shares[best] > 0:
        return brief_names[best], "share"
    nearest = min(range(len(brief_names)), key=lambda index: distances[index])
    return brief_names[nearest], "nearest"


def gather_parts(document, binary):
    """Return (name, vertices, indices) per root node with a mesh, vertices as (position, normal) in the model's frame."""
    parts = []
    for node in mesh_blob.root_nodes(document):
        if "mesh" not in node:
            continue
        transform = mesh_blob.node_transform(node)
        vertices, indices = [], []
        for primitive in document["meshes"][node["mesh"]]["primitives"]:
            mesh_blob.check_primitive(document, node.get("name"), primitive)
            positions = mesh_blob.read_accessor(document, binary, primitive["attributes"]["POSITION"])
            normals = mesh_blob.read_accessor(document, binary, primitive["attributes"]["NORMAL"])
            primitive_indices = [index for (index,) in mesh_blob.read_accessor(document, binary, primitive["indices"])]
            mesh_blob.check_indices(node.get("name"), primitive_indices, len(positions))
            offset = len(vertices)
            indices.extend(offset + index for index in primitive_indices)
            vertices.extend((mesh_blob.transform_point(transform, position), mesh_blob.rotate(transform[1], normal)) for position, normal in zip(positions, normals))
        parts.append((node.get("name"), vertices, indices))
    return parts


def ground_scale_turn(parts, height, front):
    """Move the whole model's bottom centre to the origin, scale it to the height and turn its front to +z."""
    low, high = mesh_blob.bounds([vertex for _name, vertices, _indices in parts for vertex in vertices])
    centre = ((low[0] + high[0]) / 2, low[1], (low[2] + high[2]) / 2)
    factor = height / (high[1] - low[1])

    def place(position):
        return turn(front, tuple((position[axis] - centre[axis]) * factor for axis in range(3)))

    return [(name, [(place(position), turn(front, normal)) for position, normal in vertices], indices) for name, vertices, indices in parts]


def merge(parts):
    """Return one vertex list and one index list over the parts."""
    vertices, indices = [], []
    for _name, part_vertices, part_indices in parts:
        offset = len(vertices)
        vertices.extend(part_vertices)
        indices.extend(offset + index for index in part_indices)
    return vertices, indices


def ply_header(vertex_count, face_count):
    """Return the binary little endian PLY header for positions, normals and triangle faces."""
    lines = ["ply", "format binary_little_endian 1.0", "element vertex {}".format(vertex_count)]
    lines += ["property float {}".format(name) for name in ("x", "y", "z", "nx", "ny", "nz")]
    lines += ["element face {}".format(face_count), "property list uchar int vertex_indices", "end_header"]
    return ("\n".join(lines) + "\n").encode("ascii")


def write_ply(path, vertices, indices):
    """Write the vertices as (position, normal) and the triangle indices as a binary little endian PLY."""
    floats = [value for position, normal in vertices for value in (*position, *normal)]
    with open(path, "wb") as output:
        output.write(ply_header(len(vertices), len(indices) // 3))
        output.write(struct.pack("<{}f".format(len(floats)), *floats))
        for start in range(0, len(indices), 3):
            output.write(struct.pack("<B3i", 3, *indices[start:start + 3]))


def parse_arguments():
    parser = argparse.ArgumentParser(description="Map a generated model's parts onto its brief's parts.")
    parser.add_argument("machine")
    parser.add_argument("--ply-directory", help="also write each brief part's merged mesh here as <brief part>.ply")
    return parser.parse_args()


def main():
    arguments = parse_arguments()
    machine_directory = os.path.join(ROOT, "data", "machines", arguments.machine)
    brief = read_sjson(os.path.join(machine_directory, "brief.sjson"))
    generated = read_sjson(os.path.join(machine_directory, "generated.sjson"))
    with open(os.path.join(ROOT, generated["source"]), "rb") as source:
        document, binary = mesh_blob.read_glb(source.read())
    parts = ground_scale_turn(gather_parts(document, binary), brief["height_metres"], generated["front"])
    brief_names = [brief_part["name"] for brief_part in brief["parts"]]
    boxes = [blockout_boxes(brief_part) for brief_part in brief["parts"]]
    volumes = [blockout_volume(part_boxes) for part_boxes in boxes]
    for part_name, brief_name in generated["overrides"].items():
        if brief_name not in brief_names:
            sys.exit("override {!r}: {!r} is no part of the brief".format(part_name, brief_name))
    assigned = {name: [] for name in brief_names}
    for part in parts:
        name, vertices, indices = part
        positions = [position for position, _normal in vertices]
        shares = [share_inside(positions, part_boxes, generated["margin"]) for part_boxes in boxes]
        centre = bounds_centre(positions)
        distances = [nearest_box_distance(centre, part_boxes) for part_boxes in boxes]
        brief_name, how = assign(name, generated["overrides"], brief_names, shares, distances, volumes)
        assigned[brief_name].append(part)
        note = "" if how == "share" else "  " + how
        print("{:14} {:7} triangles  {:4.0%}  {}{}".format(name, len(indices) // 3, shares[brief_names.index(brief_name)], brief_name, note))
    os.makedirs(OUTPUT_DIRECTORY, exist_ok=True)
    if arguments.ply_directory:
        os.makedirs(arguments.ply_directory, exist_ok=True)
    for brief_name in brief_names:
        if not assigned[brief_name]:
            print("{}: no generated part, no blob".format(brief_name))
            continue
        vertices, indices = merge(assigned[brief_name])
        mesh_blob.write_blob(os.path.join(OUTPUT_DIRECTORY, brief_name + ".mesh"), vertices, indices)
        if arguments.ply_directory:
            write_ply(os.path.join(arguments.ply_directory, brief_name + ".ply"), vertices, indices)
        print("{}: {} parts, {} triangles".format(brief_name, len(assigned[brief_name]), len(indices) // 3))


if __name__ == "__main__":
    main()
