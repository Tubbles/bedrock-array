"""Close the holes of a generated GLB in Blender before decimation (doc/workflows/models.md, step 1).

    flatpak run org.blender.Blender -b --python "$PWD/tools/models/close.py" -- <in.glb> <out.glb> --technique fill|voxel

fill: every mesh part gets its holes filled with faces of any side count, triangulated. voxel: the parts are joined
into one object and voxel remeshed at a voxel size of 0.01 (one percent of the model's height of about 0.9 units),
which gives one closed shell. Prints the triangle count before and after.
"""
import argparse
import sys

import bpy

VOXEL_SIZE = 0.01


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("glb_in")
    parser.add_argument("glb_out")
    parser.add_argument("--technique", choices=("fill", "voxel"), required=True)
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


def select_only(selected, active):
    for scene_object in bpy.context.scene.objects:
        scene_object.select_set(scene_object in selected)
    bpy.context.view_layer.objects.active = active


def fill_holes(part):
    select_only([part], part)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.fill_holes(sides=0)
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")


def voxel_remesh(parts):
    select_only(parts, parts[0])
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.data.remesh_voxel_size = VOXEL_SIZE
    joined.data.remesh_voxel_adaptivity = 0
    bpy.ops.object.voxel_remesh()


def main():
    arguments = parse_arguments()
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=arguments.glb_in)
    parts = mesh_parts()
    before = triangle_count(parts)
    if arguments.technique == "fill":
        for part in parts:
            fill_holes(part)
    else:
        voxel_remesh(parts)
    after = triangle_count(mesh_parts())
    print(f"closed {len(parts)} parts from {before} to {after} triangles with {arguments.technique}")
    bpy.ops.export_scene.gltf(filepath=arguments.glb_out, export_format="GLB", export_apply=True)


if __name__ == "__main__":
    main()
