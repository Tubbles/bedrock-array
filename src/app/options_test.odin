#+build !js
package app

import "core:testing"
import engine "../engine"

@(test)
test_parse_options_reads_the_shot_view_and_configuration :: proc(t: ^testing.T) {
	options, ok := parse_options({"--demo", "parts", "--shot", "tmp/shots/parts.png", "--view", "0.5,0.3,2.5,0,0.5,-1", "--configuration", "2"})
	testing.expect(t, ok)
	testing.expect_value(t, options.shot, "tmp/shots/parts.png")
	testing.expect_value(t, options.configuration, 2)
	orbit, has_view := options.view.?
	testing.expect(t, has_view)
	testing.expect_value(t, orbit, engine.Orbit{target = {0, 0.5, -1}, yaw = 0.5, pitch = 0.3, distance = 2.5})

	plain, plain_ok := parse_options({"--demo", "parts"})
	testing.expect(t, plain_ok)
	_, plain_has_view := plain.view.?
	testing.expect(t, !plain_has_view)

	_, five_ok := parse_options({"--view", "0.5,0.3,2.5,0,0.5"})
	testing.expect(t, !five_ok)
	_, word_ok := parse_options({"--view", "0.5,0.3,far,0,0.5,0"})
	testing.expect(t, !word_ok)
	_, negative_ok := parse_options({"--configuration", "-1"})
	testing.expect(t, !negative_ok)
	_, missing_ok := parse_options({"--shot"})
	testing.expect(t, !missing_ok)
}
