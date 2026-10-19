#+build !js
package engine

import "core:testing"

@(test)
test_scene_page_key_from_code :: proc(t: ^testing.T) {
	expected := []struct {
		code: string,
		key:  Scene_Page_Key,
	} {
		{"Space", .Up},
		{"ControlLeft", .Down},
		{"ControlRight", .Down},
		{"ShiftLeft", .Down},
		{"ShiftRight", .Down},
		{"KeyD", .Right},
	}
	for entry in expected {
		key, known := scene_page_key_from_code(entry.code)
		testing.expectf(t, known, "expected %v to be known", entry.code)
		testing.expectf(t, key == entry.key, "expected %v for %v, got %v", entry.key, entry.code, key)
	}
	_, known := scene_page_key_from_code("KeyZ")
	testing.expect(t, !known, "expected KeyZ to be unknown")
}
