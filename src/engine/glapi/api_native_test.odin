#+build !js
package glapi

import "core:testing"

@(test)
test_shader_source_for_desktop :: proc(t: ^testing.T) {
	web_source := "#version 300 es\nprecision highp float;\nvoid main() {}\n"
	desktop_source := shader_source_for_desktop(web_source)
	defer delete(desktop_source)
	testing.expect_value(t, desktop_source, "#version 330 core\nprecision highp float;\nvoid main() {}\n")

	plain_source := "precision highp float;\nvoid main() {}\n"
	unchanged_source := shader_source_for_desktop(plain_source)
	defer delete(unchanged_source)
	testing.expect_value(t, unchanged_source, plain_source)
}
