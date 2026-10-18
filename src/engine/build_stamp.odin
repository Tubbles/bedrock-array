package engine

import "core:strings"

// The commit and the UTC build time, separated by one space, passed by
// build.sh (doc/build.md, The build stamp).
BUILD_INFO :: #config(BUILD_INFO, "unknown")

Build_Stamp :: struct {
	commit:   string,
	built_at: string,
}

// Splits the build information at its first space. Without a space the
// whole text is the commit and the build time is empty.
build_stamp :: proc(info := BUILD_INFO) -> Build_Stamp {
	space_index := strings.index_byte(info, ' ')
	if space_index < 0 {
		return Build_Stamp{commit = info}
	}
	return Build_Stamp{commit = info[:space_index], built_at = info[space_index + 1:]}
}
