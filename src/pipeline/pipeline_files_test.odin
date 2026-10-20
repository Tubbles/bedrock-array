#+build !js
package pipeline

import "core:encoding/endian"
import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:strings"
import "core:testing"

SMELTER_MODEL :: "work/models/smelter/model_7.glb"

append_f64le :: proc(buffer: ^[dynamic]byte, value: f64) {
	encoded: [8]byte
	endian.unchecked_put_u64le(encoded[:], transmute(u64)value)
	append(buffer, ..encoded[:])
}

// A GLB of one triangle used by three meshes: with normals and u16
// indices, without normals and with u8 indices, and as a plain list.
// Root nodes "first" and "second" carry a mesh, "child" is a child and
// "empty" has no mesh.
hand_built_glb :: proc() -> []byte {
	binary := make([dynamic]byte)
	defer delete(binary)
	for value in ([]f32{0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1}) {
		append_f32le(&binary, value)
	}
	append(&binary, 0, 0, 1, 0, 2, 0, 0, 0)
	append(&binary, 0, 1, 2, 0)
	half := math.SQRT_TWO / 2
	document := fmt.tprintf(`{{"asset":{{"version":"2.0"}},
"nodes":[{{"name":"first","mesh":0,"translation":[10,0,0],"children":[2]}},{{"name":"second","mesh":1,"rotation":[0,%v,0,%v],"scale":[2,2,2]}},{{"name":"child","mesh":2}},{{"name":"empty"}}],
"meshes":[{{"primitives":[{{"attributes":{{"POSITION":0,"NORMAL":1}},"indices":2}}]}},{{"primitives":[{{"attributes":{{"POSITION":0}},"indices":3}}]}},{{"primitives":[{{"attributes":{{"POSITION":0}}}}]}}],
"accessors":[{{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"}},{{"bufferView":1,"componentType":5126,"count":3,"type":"VEC3"}},{{"bufferView":2,"componentType":5123,"count":3,"type":"SCALAR"}},{{"bufferView":3,"componentType":5121,"count":3,"type":"SCALAR"}}],
"bufferViews":[{{"buffer":0,"byteOffset":0,"byteLength":36}},{{"buffer":0,"byteOffset":36,"byteLength":36}},{{"buffer":0,"byteOffset":72,"byteLength":6}},{{"buffer":0,"byteOffset":80,"byteLength":3}}],
"buffers":[{{"byteLength":84}}]}}`, half, half)
	padded := strings.concatenate({document, strings.repeat(" ", (4 - len(document) % 4) % 4, context.temp_allocator)}, context.temp_allocator)
	glb := make([dynamic]byte)
	append_u32le(&glb, GLB_MAGIC)
	append_u32le(&glb, 2)
	append_u32le(&glb, u32(12 + 8 + len(padded) + 8 + len(binary)))
	append_u32le(&glb, u32(len(padded)))
	append_u32le(&glb, GLB_CHUNK_JSON)
	append(&glb, padded)
	append_u32le(&glb, u32(len(binary)))
	append_u32le(&glb, GLB_CHUNK_BINARY)
	append(&glb, ..binary[:])
	return glb[:]
}

@(test)
test_read_glb_of_a_hand_built_document :: proc(t: ^testing.T) {
	data := hand_built_glb()
	defer delete(data)
	mesh, problem := read_glb(data)
	defer pipeline_mesh_destroy(&mesh)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(mesh.piece_names), 2)
	testing.expect_value(t, mesh.piece_names[0], "first")
	testing.expect_value(t, mesh.piece_names[1], "second")
	testing.expect_value(t, len(mesh.triangles), 2)
	testing.expect_value(t, mesh.pieces[1], 1)
	testing.expect_value(t, mesh.parts[0], PART_NONE)
	first := mesh.triangles[0]
	expect_near(t, mesh.positions[first[1]], {11, 0, 0})
	expect_near(t, mesh.normals[first[0]], {0, 0, 1})
	// Scaled by 2, then a quarter turn about y takes +x to -z, and the
	// computed face normal turns with it.
	second := mesh.triangles[1]
	expect_near(t, mesh.positions[second[1]], {0, 0, -2})
	expect_near(t, mesh.positions[second[2]], {0, 2, 0})
	expect_near(t, mesh.normals[second[0]], {1, 0, 0})
	_, not_glb_problem := read_glb(transmute([]byte)string("not a glb file at all"))
	testing.expect(t, not_glb_problem != "")
}

@(test)
test_ply_round_trip :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	mesh.normals[5] = {0, 0, 1}
	data := ply_bytes(mesh, []bool{false, false, true, true})
	defer delete(data)
	testing.expect(t, strings.has_prefix(string(data), "ply\nformat binary_little_endian 1.0\nelement vertex 4\nproperty float x\n"))
	read, problem := read_ply(data)
	defer pipeline_mesh_destroy(&read)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(read.positions), 4)
	testing.expect_value(t, len(read.triangles), 2)
	testing.expect_value(t, read.triangles[1], [3]u32{0, 2, 3})
	expect_near(t, read.positions[1], {3, 0, 0})
	expect_near(t, read.normals[1], {0, 0, 1})
	expect_near(t, read.normals[2], {0, 1, 0})
}

@(test)
test_read_meshlab_ply_with_quality :: proc(t: ^testing.T) {
	data := make([dynamic]byte)
	defer delete(data)
	append(&data, "ply\nformat binary_little_endian 1.0\ncomment VCGLIB generated\nelement vertex 3\nproperty double x\nproperty double y\nproperty double z\nproperty double quality\nproperty uchar red\nelement face 1\nproperty list uchar uint vertex_indices\nend_header\n")
	for position in ([][3]f64{{0, 0, 0}, {1, 0, 0}, {0, 1, 0}}) {
		for value in position {
			append_f64le(&data, value)
		}
		append_f64le(&data, 0.5)
		append(&data, 200)
	}
	append(&data, 3)
	for vertex in ([]u32{0, 1, 2}) {
		append_u32le(&data, vertex)
	}
	mesh, problem := read_ply(data[:])
	defer pipeline_mesh_destroy(&mesh)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(mesh.positions), 3)
	testing.expect_value(t, len(mesh.triangles), 1)
	expect_near(t, mesh.positions[1], {1, 0, 0})
	expect_near(t, mesh.positions[2], {0, 1, 0})
	expect_near(t, mesh.normals[0], {0, 0, 1})
	_, short_problem := read_ply(data[:len(data) - 2])
	testing.expect(t, short_problem != "")
}

blob_counts :: proc(data: []byte) -> (vertex_count, index_count: int) {
	return int(endian.unchecked_get_u32le(data[8:])), int(endian.unchecked_get_u32le(data[12:]))
}

@(test)
test_part_blobs_split_by_part :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	step_assign(&mesh, "body", []bool{true, true, false, false})
	step_assign(&mesh, "lid", []bool{false, false, true, false})
	step_assign(&mesh, "unused", []bool{false, false, false, false})
	directory, directory_error := os.make_directory_temp("", "pipeline_test_*", context.allocator)
	defer delete(directory)
	testing.expect_value(t, directory_error, nil)
	defer os.remove_all(directory)
	testing.expect_value(t, write_part_blobs(mesh, directory, "_level0"), "")
	body, body_error := os.read_entire_file_from_path(fmt.tprintf("%s/body_level0.mesh", directory), context.allocator)
	defer delete(body)
	testing.expect_value(t, body_error, nil)
	lid, lid_error := os.read_entire_file_from_path(fmt.tprintf("%s/lid_level0.mesh", directory), context.allocator)
	defer delete(lid)
	testing.expect_value(t, lid_error, nil)
	testing.expect(t, !os.exists(fmt.tprintf("%s/unused_level0.mesh", directory)))
	testing.expect_value(t, string(body[:8]), MESH_BLOB_MAGIC)
	body_vertices, body_indices := blob_counts(body)
	testing.expect_value(t, body_vertices, 4)
	testing.expect_value(t, body_indices, 6)
	testing.expect_value(t, len(body), 16 + 24 * 4 + 4 * 6)
	lid_vertices, lid_indices := blob_counts(lid)
	testing.expect_value(t, lid_vertices, 3)
	testing.expect_value(t, lid_indices, 3)
	testing.expect_value(t, transmute(f32)endian.unchecked_get_u32le(lid[16:]), 2)
}

@(test)
test_read_the_smelter_model :: proc(t: ^testing.T) {
	if !os.exists(SMELTER_MODEL) {
		log.infof("skipped: %s is absent", SMELTER_MODEL)
		return
	}
	data, read_error := os.read_entire_file_from_path(SMELTER_MODEL, context.allocator)
	defer delete(data)
	testing.expect_value(t, read_error, nil)
	mesh, problem := read_glb(data)
	defer pipeline_mesh_destroy(&mesh)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(mesh.piece_names), 29)
	testing.expect_value(t, len(mesh.triangles), 1461245)
}
