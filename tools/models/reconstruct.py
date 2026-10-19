#!/usr/bin/env -S uv run --python 3.12 --with pymeshlab python -I
"""Rebuild a generated GLB as one closed surface with MeshLab before decimation (doc/workflows/models.md, step 1).

    tools/models/reconstruct.py <in.glb> <out.ply> --technique poisson|alphawrap [--depth <n>]

The layers are merged into one mesh first. poisson: screened Poisson reconstruction at octree depth 9 (or --depth) with
1.5 samples per node, a smooth watertight surface through the points. alphawrap: an alpha wrap with alpha at one percent
and the offset at 0.1 percent of the bounding box diagonal, a shrink wrapped shell around the model. Prints the face
count before and after and saves the result as PLY.
"""
import argparse

import pymeshlab


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("glb_in")
    parser.add_argument("ply_out")
    parser.add_argument("--technique", choices=("poisson", "alphawrap"), required=True)
    parser.add_argument("--depth", type=int, default=9)
    return parser.parse_args()


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
    reconstruct(mesh_set, arguments.technique, arguments.depth)
    after = mesh_set.current_mesh().face_number()
    print(f"reconstructed {before} to {after} faces with {arguments.technique}")
    mesh_set.save_current_mesh(arguments.ply_out)


if __name__ == "__main__":
    main()
