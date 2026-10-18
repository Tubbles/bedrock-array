"""Build a machine's blockout from its brief and render the hero view, the four orthographic views and a mask of each.

Step 2 of doc/workflows/art_book.md. Run from the repository root as
`flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- <id>`;
the images go to work/art/<id>/blockout/.

The brief is y up with the front facing +z; Blender is z up, so the brief's
[x, y, z] is Blender's (x, -z, y) and the front faces Blender's -y.
"""

import math
import os
import sys

import bpy
import bmesh
import numpy
from mathutils import Vector

SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIRECTORY))
sys.path.insert(0, os.path.join(REPOSITORY_ROOT, "tools", "materials"))

import images  # noqa: E402
import review  # noqa: E402

FIGURE_RADIUS = 0.2
FIGURE_GAP_METRES = 1.4
HERO_ELEVATION_DEGREES = 15
HERO_MARGIN = 0.1
ORTHOGRAPHIC_SCALE_FACTOR = 1.2
ORTHOGRAPHIC_DISTANCE = 10.0
ORTHOGRAPHIC_VIEWS = {
    "front": Vector((0, -1, 0)),
    "left": Vector((-1, 0, 0)),
    "back": Vector((0, 1, 0)),
    "right": Vector((1, 0, 0)),
}


# Reading


def read_brief(machine_id):
    return review.read_sjson("data", "machines", machine_id, "brief.sjson")


def read_library():
    return review.read_sjson("data", "materials", "library.sjson")


def to_blender(brief_vector):
    """The brief's y up [x, y, z] as Blender's z up (x, -z, y)."""
    return Vector((brief_vector[0], -brief_vector[2], brief_vector[1]))


# Materials


def preset_material(name, preset):
    material = bpy.data.materials.new(name)
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*preset["albedo"], 1)
    shader.inputs["Roughness"].default_value = preset["roughness"]
    shader.inputs["Metallic"].default_value = preset["metallic"]
    if "emissive" in preset:
        shader.inputs["Emission Color"].default_value = (*preset["emissive"], 1)
        shader.inputs["Emission Strength"].default_value = 1.0
    return material


def grey_material():
    material = bpy.data.materials.new("figure")
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (0.18, 0.18, 0.18, 1)
    shader.inputs["Roughness"].default_value = 0.8
    return material


def white_emission_material():
    material = bpy.data.materials.new("mask")
    tree = material.node_tree
    for node in list(tree.nodes):
        tree.nodes.remove(node)
    emission = tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (1, 1, 1, 1)
    emission.inputs["Strength"].default_value = 1.0
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    tree.links.new(emission.outputs[0], output.inputs["Surface"])
    return material


# Shapes


def add_box_shape(blockout):
    bpy.ops.mesh.primitive_cube_add(size=1, location=to_blender(blockout["position"]))
    box = bpy.context.active_object
    width, height, depth = blockout["size"]
    box.scale = (width, depth, height)
    return box


def add_cylinder_shape(blockout):
    location = to_blender(blockout["position"])
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=blockout["radius"], depth=blockout["height"], location=location)
    return bpy.context.active_object


def delete_lower_half(mesh):
    """Removes the vertices below the mesh's centre, leaving the upper hemisphere open at its base."""
    editable = bmesh.new()
    editable.from_mesh(mesh)
    lower = [vertex for vertex in editable.verts if vertex.co.z < -1e-6]
    bmesh.ops.delete(editable, geom=lower, context="VERTS")
    editable.to_mesh(mesh)
    editable.free()


def add_dome_shape(blockout):
    """The upper half of a sphere of the radius, scaled to the height, its base at the position."""
    radius = blockout["radius"]
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=radius, location=to_blender(blockout["position"]))
    dome = bpy.context.active_object
    delete_lower_half(dome.data)
    dome.scale = (1, 1, blockout["height"] / radius)
    return dome


SHAPE_BUILDERS = {"box": add_box_shape, "cylinder": add_cylinder_shape, "dome": add_dome_shape}


def shape_names(part):
    """The part's name for a single shape, `<part>.<index>` for each shape of a list."""
    blockout = part["blockout"]
    if isinstance(blockout, dict):
        return [(part["name"], blockout)]
    return [("%s.%d" % (part["name"], index), shape) for index, shape in enumerate(blockout)]


def add_bevel(part_object, bevel):
    """A bevel modifier of the shape's width and segments, on the edges sharper than the angle limit."""
    modifier = part_object.modifiers.new("bevel", "BEVEL")
    modifier.width = bevel["width"]
    modifier.segments = bevel["segments"]
    modifier.limit_method = "ANGLE"


def add_part(part, library):
    """One object per shape of the part's blockout, all with the part's material."""
    material = preset_material(part["name"], library[part["material"]])
    part_objects = []
    for name, shape in shape_names(part):
        part_object = SHAPE_BUILDERS[shape["shape"]](shape)
        part_object.name = name
        # Applied so a bevel's width is in metres, not in the shape's unscaled space.
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if "bevel" in shape:
            add_bevel(part_object, shape["bevel"])
        bpy.ops.object.shade_auto_smooth()
        part_object.data.materials.append(material)
        part_objects.append(part_object)
    return part_objects


# Figure


def figure_location(brief):
    """On the ground at FIGURE_GAP_METRES to the machine's right (+x), level with its front."""
    half_depth = brief["footprint"]["cells"][1] * brief["footprint"]["cell_metres"] / 2
    return to_blender([FIGURE_GAP_METRES, 0, half_depth])


def add_figure(brief):
    """A capsule of the figure's height: a cylinder of FIGURE_RADIUS and a sphere head on top."""
    base = figure_location(brief)
    height = brief["figure_metres"]
    body_height = height - 2 * FIGURE_RADIUS
    material = grey_material()
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=FIGURE_RADIUS, depth=body_height, location=base + Vector((0, 0, body_height / 2)))
    body = bpy.context.active_object
    bpy.ops.mesh.primitive_uv_sphere_add(radius=FIGURE_RADIUS, location=base + Vector((0, 0, height - FIGURE_RADIUS)))
    head = bpy.context.active_object
    for figure_object in (body, head):
        bpy.ops.object.select_all(action="DESELECT")
        figure_object.select_set(True)
        bpy.context.view_layer.objects.active = figure_object
        bpy.ops.object.shade_smooth()
        figure_object.data.materials.append(material)
    return [body, head]


# Scene


def build_scene(brief, library):
    """The sheet's render settings, ground, sun and sky, square; the parts and the figure."""
    scene = review.reset_scene()
    scene.render.resolution_y = 1024
    scene.render.image_settings.color_mode = "RGB"
    parts = [part_object for part in brief["parts"] for part_object in add_part(part, library)]
    figure = add_figure(brief)
    review.add_ground()
    ground = bpy.context.active_object
    # The sheet's ground sits under its two metre boxes at z = -1; the brief's footprint stands on z = 0.
    ground.location.z = 0
    review.add_light_camera_world(scene)
    bpy.data.objects.remove(scene.camera)
    return scene, parts, figure, ground


# Cameras


def look_at(camera, target):
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def bounding_corners(objects):
    bpy.context.view_layer.update()
    return [scene_object.matrix_world @ Vector(corner) for scene_object in objects for corner in scene_object.bound_box]


def hero_direction():
    """From the target towards the camera: three quarters from the front left (Blender -x, -y), a little above."""
    elevation = math.radians(HERO_ELEVATION_DEGREES)
    horizontal = math.cos(elevation) / math.sqrt(2)
    return Vector((-horizontal, -horizontal, math.sin(elevation)))


def add_hero_camera(framed_objects):
    """Fitted to the framed objects' corners along the hero direction, then widened by the margin on each side."""
    corners = bounding_corners(framed_objects)
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.name = "hero"
    camera.rotation_euler = (-hero_direction()).to_track_quat("-Z", "Y").to_euler()
    coordinates = [component for corner in corners for component in corner]
    location, _ = camera.camera_fit_coords(bpy.context.evaluated_depsgraph_get(), coordinates)
    camera.location = location
    camera.data.lens *= 1 - 2 * HERO_MARGIN
    return camera


def orthographic_scale(brief):
    footprint = brief["footprint"]
    width = footprint["cells"][0] * footprint["cell_metres"]
    depth = footprint["cells"][1] * footprint["cell_metres"]
    return ORTHOGRAPHIC_SCALE_FACTOR * max(brief["height_metres"], math.hypot(width, depth))


def add_orthographic_camera(name, side, brief):
    target = Vector((0, 0, brief["height_metres"] / 2))
    bpy.ops.object.camera_add(location=target + side * ORTHOGRAPHIC_DISTANCE)
    camera = bpy.context.active_object
    camera.name = name
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = orthographic_scale(brief)
    look_at(camera, target)
    return camera


def add_cameras(scene, brief, parts, figure):
    cameras = {"hero": add_hero_camera(parts + figure)}
    for name, side in ORTHOGRAPHIC_VIEWS.items():
        cameras[name] = add_orthographic_camera(name, side, brief)
    return cameras


# Render


def render_view(scene, camera, path):
    scene.camera = camera
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def black_world():
    world = bpy.data.worlds.new("black")
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0
    return world


def prepare_mask(scene, hidden_objects):
    """The figure and the ground hidden, a black world, every part white, no tone mapping."""
    for hidden_object in hidden_objects:
        hidden_object.hide_render = True
    scene.world = black_world()
    scene.view_layers[0].material_override = white_emission_material()
    scene.view_settings.view_transform = "Standard"
    scene.render.dither_intensity = 0


def render_all(scene, cameras, hidden_objects, directory):
    for name, camera in cameras.items():
        render_view(scene, camera, os.path.join(directory, name + ".png"))
    prepare_mask(scene, hidden_objects)
    for name, camera in cameras.items():
        path = os.path.join(directory, name + "_mask.png")
        render_view(scene, camera, path)
        threshold_mask(path)


def threshold_mask(path):
    """The render's edge antialiasing leaves grey pixels; the mask is the pixels above half."""
    pixels = review.read_png(path)
    mask = (pixels[..., :1] > 0.5).astype(numpy.float64)
    # The reader gives the top row first, the writer takes the bottom row first (the bake's convention).
    images.write_png(path, numpy.repeat(mask, 3, axis=2)[::-1], "linear")


# Main


def main():
    machine_id = sys.argv[sys.argv.index("--") + 1]
    brief = read_brief(machine_id)
    scene, parts, figure, ground = build_scene(brief, read_library())
    cameras = add_cameras(scene, brief, parts, figure)
    directory = os.path.join(REPOSITORY_ROOT, "work", "art", machine_id, "blockout")
    os.makedirs(directory, exist_ok=True)
    render_all(scene, cameras, figure + [ground], directory)


if __name__ == "__main__":
    main()
