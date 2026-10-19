"""Decimate a generated GLB in Blender to a triangle budget, the comparison for Tripo's own reductions (doc/workflows/models.md, step 1).

    flatpak run org.blender.Blender -b --python "$PWD/tools/models/decimate.py" -- <in.glb> <out.glb> --triangles <n>

Every mesh part gets a collapse decimate at the one ratio that brings the whole model to the budget, so a part keeps its share of the triangles. Prints the triangle count before and after.
"""
import argparse
import sys

import bpy


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("glb_in")
    parser.add_argument("glb_out")
    parser.add_argument("--triangles", type=int, required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def mesh_parts():
    return [scene_object for scene_object in bpy.context.scene.objects if scene_object.type == "MESH"]


def triangle_count(parts):
    for part in parts:
        part.data.calc_loop_triangles()
    return sum(len(part.data.loop_triangles) for part in parts)


def decimate(part, ratio):
    modifier = part.modifiers.new("decimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = part
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def main():
    arguments = parse_arguments()
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=arguments.glb_in)
    parts = mesh_parts()
    before = triangle_count(parts)
    ratio = min(1.0, arguments.triangles / max(before, 1))
    for part in parts:
        decimate(part, ratio)
    after = triangle_count(parts)
    print(f"decimated {len(parts)} parts from {before} to {after} triangles at ratio {ratio:.5f}")
    bpy.ops.export_scene.gltf(filepath=arguments.glb_out, export_format="GLB", export_apply=True)


if __name__ == "__main__":
    main()
