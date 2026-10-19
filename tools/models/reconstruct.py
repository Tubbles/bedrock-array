#!/usr/bin/env -S uv run --python 3.12 --with pymeshlab python -I
"""Rebuild a generated GLB as one closed surface with MeshLab before decimation (doc/workflows/models.md, step 1).

    tools/models/reconstruct.py <in.glb|in.ply> <out.ply> --technique poisson|alphawrap [--depth <n> | --cell <metres>] [--trim <metres>]

The layers are merged into one mesh first. poisson: screened Poisson reconstruction at octree depth 9 (or --depth) with
1.5 samples per node, a smooth watertight surface through the points. --cell picks the depth instead, the smallest whose
cell (1.1 times the largest bounding box extent over 2 to the depth) is at most the given size, clamped to 4..10, and
prints it. --trim removes the closed vertices farther than the given distance from the input with their faces, then
the pieces left with fewer than MINIMUM_PIECE_FACES faces, so the surface Poisson adds over an open side goes again.
alphawrap: an alpha wrap with alpha at one percent and the offset at 0.1 percent of the bounding box
diagonal, a shrink wrapped shell around the model. Prints the face count before and after and saves the result as PLY.
"""
import argparse
import math

import pymeshlab

DEPTH_RANGE = (4, 10)
MINIMUM_PIECE_FACES = 100


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("glb_in")
    parser.add_argument("ply_out")
    parser.add_argument("--technique", choices=("poisson", "alphawrap"), required=True)
    sizes = parser.add_mutually_exclusive_group()
    sizes.add_argument("--depth", type=int)
    sizes.add_argument("--cell", type=float, help="Poisson cell size in metres, picks the depth")
    parser.add_argument("--trim", type=float, help="remove the closed surface farther than this from the input, in metres")
    arguments = parser.parse_args()
    if arguments.technique != "poisson" and (arguments.cell is not None or arguments.trim is not None):
        parser.error("--cell and --trim are for poisson only")
    return arguments


def depth_for_cell(largest_extent, cell):
    """Return the octree depth whose cell over 1.1 times the extent is at most the cell size, clamped."""
    depth = math.ceil(math.log2(1.1 * largest_extent / cell))
    return max(DEPTH_RANGE[0], min(DEPTH_RANGE[1], depth))


def far_condition(trim):
    """Return MeshLab's vertex selection condition for a distance in the vertex quality above the trim."""
    return f"(q > {trim!r})"


def trim_far_surface(mesh_set, input_id, trim):
    """Remove the current mesh's vertices farther than the trim from the input mesh, their faces and small pieces."""
    closed_id = mesh_set.current_mesh_id()
    mesh_set.compute_scalar_by_distance_from_another_mesh_per_vertex(measuremesh=closed_id, refmesh=input_id, signeddist=False, maxdist=pymeshlab.PercentageValue(100))
    mesh_set.set_current_mesh(closed_id)
    mesh_set.compute_selection_by_condition_per_vertex(condselect=far_condition(trim))
    mesh_set.meshing_remove_selected_vertices()
    mesh_set.meshing_remove_unreferenced_vertices()
    mesh_set.meshing_remove_connected_component_by_face_number(mincomponentsize=MINIMUM_PIECE_FACES, removeunref=True)


def largest_extent(mesh_set):
    box = mesh_set.current_mesh().bounding_box()
    return max(box.dim_x(), box.dim_y(), box.dim_z())


def load_merged(path):
    mesh_set = pymeshlab.MeshSet()
    mesh_set.load_new_mesh(path)
    if mesh_set.mesh_number() > 1:
        mesh_set.generate_by_merging_visible_meshes()
    return mesh_set


def reconstruct(mesh_set, technique, depth):
    if technique == "poisson":
        mesh_set.generate_surface_reconstruction_screened_poisson(depth=depth, samplespernode=1.5, preclean=True)
    else:
        mesh_set.generate_alpha_wrap(alpha=pymeshlab.PercentageValue(1), offset=pymeshlab.PercentageValue(0.1))


def main():
    arguments = parse_arguments()
    mesh_set = load_merged(arguments.glb_in)
    before = mesh_set.current_mesh().face_number()
    depth = arguments.depth if arguments.depth is not None else 9
    if arguments.cell is not None:
        depth = depth_for_cell(largest_extent(mesh_set), arguments.cell)
        print(f"depth {depth} for a cell of {arguments.cell} m")
    input_id = mesh_set.current_mesh_id()
    reconstruct(mesh_set, arguments.technique, depth)
    after = mesh_set.current_mesh().face_number()
    print(f"reconstructed {before} to {after} faces with {arguments.technique}")
    if arguments.trim is not None:
        trim_far_surface(mesh_set, input_id, arguments.trim)
        print(f"trimmed {after} to {mesh_set.current_mesh().face_number()} faces farther than {arguments.trim} m from the input")
    mesh_set.save_current_mesh(arguments.ply_out)


if __name__ == "__main__":
    main()
