package engine

import "core:testing"

@(test)
test_build_stamp_splits_commit_and_time :: proc(t: ^testing.T) {
	stamp := build_stamp("a1b2c3d+dirty 2026-10-18T12:00Z")
	testing.expect_value(t, stamp.commit, "a1b2c3d+dirty")
	testing.expect_value(t, stamp.built_at, "2026-10-18T12:00Z")
}

@(test)
test_build_stamp_without_time_is_the_commit :: proc(t: ^testing.T) {
	stamp := build_stamp("unknown")
	testing.expect_value(t, stamp.commit, "unknown")
	testing.expect_value(t, stamp.built_at, "")
}
