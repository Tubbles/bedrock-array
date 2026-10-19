"""Decimate a generated GLB, or a closed PLY from reconstruct.py, in Blender to a triangle budget, the comparison for Tripo's own reductions (doc/workflows/models.md, step 1).

    flatpak run org.blender.Blender -b --python "$PWD/tools/models/decimate.py" -- <in.glb|in.ply> <out.glb> --triangles <n>

A .ply input goes through Blender's PLY importer with Y up, the glTF axes reconstruct.py keeps, anything else through the glTF importer.
Every mesh part gets a collapse decimate at the one ratio that brings the whole model to the budget, so a part keeps its share of the triangles. Prints the triangle count before and after.
The parts are then shaded smooth by angle: an edge sharper than SMOOTH_ANGLE_DEGREES keeps split normals, the rest share their vertices, so the export is not one vertex triple per triangle as a flat shaded mesh would be.
"""
import argparse
import math
import sys

import bpy

SMOOTH_ANGLE_DEGREES = 30


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("mesh_in")
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


def import_mesh(path):
    if path.lower().endswith(".ply"):
        bpy.ops.wm.ply_import(filepath=path, forward_axis="NEGATIVE_Z", up_axis="Y")
    else:
        bpy.ops.import_scene.gltf(filepath=path)


def decimate(part, ratio):
    modifier = part.modifiers.new("decimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = part
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def shade_smooth(parts):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(SMOOTH_ANGLE_DEGREES))


def main():
    arguments = parse_arguments()
    reset_scene()
    import_mesh(arguments.mesh_in)
    parts = mesh_parts()
    before = triangle_count(parts)
    ratio = min(1.0, arguments.triangles / max(before, 1))
    for part in parts:
        decimate(part, ratio)
    after = triangle_count(parts)
    shade_smooth(parts)
    print(f"decimated {len(parts)} parts from {before} to {after} triangles at ratio {ratio:.5f}")
    bpy.ops.export_scene.gltf(filepath=arguments.glb_out, export_format="GLB", export_apply=True)


if __name__ == "__main__":
    main()
