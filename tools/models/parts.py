#!/usr/bin/env python3
"""Map a generated model's parts onto its brief's parts and write one mesh blob per brief part (doc/workflows/models.md, the finish step).

    python3 -I tools/models/parts.py <machine> [--ply-directory <dir>]
    python3 -I tools/models/parts.py <machine> --closings

Reads data/machines/<machine>/brief.sjson and generated.sjson, gathers each root node's mesh, moves the
whole model's bounding box bottom centre to the origin, scales it to the brief's height and turns the
generated front to the brief's +z. Each generated part goes to its override, else to the brief part with
the largest share of its vertices inside one of that part's blockout boxes grown by the margin (equal
shares to the smaller blockout), else to the brief part with the box centre nearest its bounding box
centre. Then the extractions of generated.sjson cut the screws fused into the body and the skirt out
into the fittings, and the additions fill empty screw holes with copies of them. Writes data/demos/parts/meshes/<brief part>.mesh in the brief's frame and prints one line per
generated part. With --ply-directory each brief part's merged mesh is also written there as <brief part>.ply,
for the closing by reconstruct.py. --closings prints one "<brief part> <closing>" line per brief part with a
blob, the closing from generated.sjson ("poisson" when the part is not listed, or "none"), and exits.
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
CLOSINGS = ("poisson", "none")
DEFAULT_CLOSING = "poisson"
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


FACINGS = {"+x": (0, 1), "-x": (0, -1), "+y": (1, 1), "-y": (1, -1), "+z": (2, 1), "-z": (2, -1)}
DEPTH_WINDOW = 0.025
RING_WIDTH = 0.001
RING_COUNT = 16
HEAD_RADIUS = 0.003
FLOOR_START = 0.004
PANEL_RING = (0.013, 0.016)
HEAD_RISE = 0.002


def subtract(a, b):
    """Return a minus b."""
    return tuple(a[axis] - b[axis] for axis in range(3))


def add(a, b):
    """Return a plus b."""
    return tuple(a[axis] + b[axis] for axis in range(3))


def dot(a, b):
    """Return the dot product."""
    return sum(a[axis] * b[axis] for axis in range(3))


def cross(a, b):
    """Return the cross product."""
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def multiply(matrix, vector):
    """Return the matrix given as rows times the vector."""
    return tuple(dot(row, vector) for row in matrix)


def centroid(positions):
    """Return the mean of the positions."""
    return tuple(sum(column) / len(positions) for column in zip(*positions))


def facing_vector(facing):
    """Return the unit vector of a facing such as "+x"."""
    axis, sign = FACINGS[facing]
    return tuple(sign if index == axis else 0 for index in range(3))


def height(position, facing):
    """Return the position's coordinate along the facing."""
    axis, sign = FACINGS[facing]
    return sign * position[axis]


def across(position, point, facing):
    """Return the distance from the position to the point measured in the plane of the face."""
    axis, _sign = FACINGS[facing]
    return math.hypot(*(position[index] - point[index] for index in range(3) if index != axis))


def at_height(point, facing, value):
    """Return the point moved along the facing to the height."""
    axis, sign = FACINGS[facing]
    return tuple(sign * value if index == axis else point[index] for index in range(3))


def within(position, point, facing, radius):
    """Whether the position lies within the radius of the point across the face and within the depth window along it."""
    return across(position, point, facing) <= radius and abs(height(position, facing) - height(point, facing)) <= DEPTH_WINDOW


def median(values):
    """Return the median of the values."""
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


def heights_in_ring(point, facing, positions, inner, outer):
    """Return the heights of the positions from inner to outer across the face of the point, within the depth window."""
    return [height(position, facing) for position in positions
            if inner <= across(position, point, facing) < outer and abs(height(position, facing) - height(point, facing)) <= DEPTH_WINDOW]


def panel_level(point, facing, positions):
    """Return the median height of the positions in the 13 to 16 mm ring around the point, the panel around the spot."""
    heights = heights_in_ring(point, facing, positions, *PANEL_RING)
    if not heights:
        fail("no vertex near {}".format(list(point)))
    return median(heights)


def ring_medians(point, facing, positions):
    """Return the median height per 1 mm ring around the point's axis out to 16 mm, None for an empty ring."""
    rings = [[] for _ring in range(RING_COUNT)]
    for position in positions:
        if within(position, point, facing, RING_COUNT * RING_WIDTH):
            ring = int(across(position, point, facing) / RING_WIDTH)
            if ring < RING_COUNT:
                rings[ring].append(height(position, facing))
    return [median(heights) if heights else None for heights in rings]


def cut_radius(point, facing, positions):
    """Return (cut radius, half radius, floor radius) of the screw head at the point.

    The head top is the median height within 3 mm, the floor the lowest ring median beyond 4 mm, the half
    radius the middle of the first ring whose median falls below the midpoint of the two, and the cut lies
    halfway between the half radius and the floor. A head less than 2 mm above the floor is no screw.
    """
    medians = ring_medians(point, facing, positions)
    head = heights_in_ring(point, facing, positions, 0.0, HEAD_RADIUS)
    floor_rings = [ring for ring in range(round(FLOOR_START / RING_WIDTH), RING_COUNT) if medians[ring] is not None]
    if not head or not floor_rings:
        fail("no vertex near {}".format(list(point)))
    head_top = median(head)
    floor_ring = min(floor_rings, key=lambda ring: medians[ring])
    if head_top - medians[floor_ring] < HEAD_RISE:
        fail("no screw at {}: the head is {:.1f} mm above the floor".format(list(point), 1000 * (head_top - medians[floor_ring])))
    midpoint = (head_top + medians[floor_ring]) / 2
    half_ring = next(ring for ring in range(RING_COUNT) if medians[ring] is not None and medians[ring] < midpoint)
    half_radius, floor_radius = (half_ring + 0.5) * RING_WIDTH, (floor_ring + 0.5) * RING_WIDTH
    return (half_radius + floor_radius) / 2, half_radius, floor_radius


def compact(vertices, triangles):
    """Return the vertices the triangles use and the triangles' indices into them."""
    remap, kept, indices = {}, [], []
    for triangle in triangles:
        for index in triangle:
            if index not in remap:
                remap[index] = len(kept)
                kept.append(vertices[index])
            indices.append(remap[index])
    return kept, indices


def split_mesh(vertices, indices, taken):
    """Return (left mesh, taken mesh) from a flag per triangle."""
    triangles = [indices[start:start + 3] for start in range(0, len(indices), 3)]
    left = [triangle for triangle, flag in zip(triangles, taken) if not flag]
    return compact(vertices, left), compact(vertices, [triangle for triangle, flag in zip(triangles, taken) if flag])


def cut_out(host_parts, point, facing, radius):
    """Return the host's generated parts without the triangles whose centroid lies within the radius of the point's axis, and those triangles as one mesh."""
    remaining, cut = [], []
    for name, vertices, indices in host_parts:
        centres = [centroid([vertices[index][0] for index in indices[start:start + 3]]) for start in range(0, len(indices), 3)]
        taken = [within(centre, point, facing, radius) for centre in centres]
        (kept, kept_indices), cut_mesh = split_mesh(vertices, indices, taken)
        remaining.append((name, kept, kept_indices))
        cut.append((name, *cut_mesh))
    return remaining, merge(cut)


def quarter_turn(from_facing, to_facing):
    """Return the rotation as rows that turns from_facing to to_facing by quarter turns, about y when both are level."""
    source, target = facing_vector(from_facing), facing_vector(to_facing)
    if source == target:
        return ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    if source == tuple(-value for value in target):
        axis = (0, 1, 0) if source[1] == 0 else (1, 0, 0)
        return tuple(tuple(2 * axis[row] * axis[column] - (1 if row == column else 0) for column in range(3)) for row in range(3))
    axis = cross(source, target)
    skew = ((0, -axis[2], axis[1]), (axis[2], 0, -axis[0]), (-axis[1], axis[0], 0))
    return tuple(tuple(axis[row] * axis[column] + skew[row][column] for column in range(3)) for row in range(3))


def place_copy(vertices, rotation, from_centre, to_centre):
    """Return the vertices turned by the rotation about from_centre and moved from it to to_centre."""
    return [(add(multiply(rotation, subtract(position, from_centre)), to_centre), multiply(rotation, normal)) for position, normal in vertices]


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


def closing_for(closings, brief_name):
    """Return the brief part's closing, the default when it is not listed; an unknown closing is an error."""
    closing = closings.get(brief_name, DEFAULT_CLOSING)
    if closing not in CLOSINGS:
        fail("closing of {!r}: {!r} is none of {}".format(brief_name, closing, ", ".join(CLOSINGS)))
    return closing


def fail(message):
    """Exit with the message and status 1."""
    sys.exit(message)


def print_closings(brief, generated):
    """Print one line per brief part with a blob: its name and its closing."""
    closings = generated.get("closing", {})
    brief_names = [brief_part["name"] for brief_part in brief["parts"]]
    for name in closings:
        if name not in brief_names:
            fail("closing: {!r} is no part of the brief".format(name))
    for name in brief_names:
        if os.path.exists(os.path.join(OUTPUT_DIRECTORY, name + ".mesh")):
            print(name, closing_for(closings, name))


def host_of(point, assigned):
    """Return the name of the brief part other than the fittings that holds the vertex nearest the point."""
    best_name, best_distance = None, math.inf
    for brief_name, brief_parts in assigned.items():
        if brief_name == "fittings":
            continue
        for _name, vertices, _indices in brief_parts:
            for position, _normal in vertices:
                distance = math.dist(position, point)
                if distance < best_distance:
                    best_name, best_distance = brief_name, distance
    return best_name


def host_positions(host_parts):
    """Return every position of the host's generated parts."""
    return [position for _name, vertices, _indices in host_parts for position, _normal in vertices]


def repair(generated, assigned):
    """Cut each extraction's screw out of its host into the fittings, then fill each addition's hole with a copy of one.

    A copy moves across the face from its source's near point to the addition's and along the facing by the
    difference of their panel levels, so the head keeps its height above its panel.
    """
    cuts = []
    for number, extraction in enumerate(generated.get("extractions", [])):
        point, facing = extraction["near"], extraction["facing"]
        host = host_of(point, assigned)
        positions = host_positions(assigned[host])
        radius, half_radius, floor_radius = cut_radius(point, facing, positions)
        anchor = at_height(point, facing, panel_level(point, facing, positions))
        assigned[host], (vertices, indices) = cut_out(assigned[host], point, facing, radius)
        assigned["fittings"].append(("screw_{}".format(number), vertices, indices))
        cuts.append((anchor, facing, vertices, indices))
        print("screw_{:<3} {:6} half {:4.1f} mm  floor {:4.1f} mm  cut {:4.1f} mm  {:5} triangles".format(
            number, host, 1000 * half_radius, 1000 * floor_radius, 1000 * radius, len(indices) // 3))
    for number, addition in enumerate(generated.get("additions", [])):
        if not 0 <= addition["copy"] < len(cuts):
            fail("addition {}: copy {} is no extraction".format(number, addition["copy"]))
        point, facing = addition["near"], addition["facing"]
        host = host_of(point, assigned)
        anchor = at_height(point, facing, panel_level(point, facing, host_positions(assigned[host])))
        source_anchor, source_facing, vertices, indices = cuts[addition["copy"]]
        copy = place_copy(vertices, quarter_turn(source_facing, facing), source_anchor, anchor)
        assigned["fittings"].append(("addition_{}".format(number), copy, list(indices)))
        print("addition_{:<3} {:6} copy of screw_{}  panel {}  moved {:.1f} mm".format(
            number, host, addition["copy"], format_point(anchor), 1000 * math.dist(anchor, source_anchor)))


def format_point(point):
    """Return the point as a short text in metres."""
    return "({:+.4f}, {:+.4f}, {:+.4f})".format(*point)


def parse_arguments():
    parser = argparse.ArgumentParser(description="Map a generated model's parts onto its brief's parts.")
    parser.add_argument("machine")
    parser.add_argument("--ply-directory", help="also write each brief part's merged mesh here as <brief part>.ply")
    parser.add_argument("--closings", action="store_true", help="print each brief part's closing and exit")
    return parser.parse_args()


def main():
    arguments = parse_arguments()
    machine_directory = os.path.join(ROOT, "data", "machines", arguments.machine)
    brief = read_sjson(os.path.join(machine_directory, "brief.sjson"))
    generated = read_sjson(os.path.join(machine_directory, "generated.sjson"))
    if arguments.closings:
        print_closings(brief, generated)
        return
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
    repair(generated, assigned)
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
