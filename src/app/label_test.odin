#+build !js
package app

import "core:testing"

@(private = "file")
measure_length :: proc(text: string) -> int {
	return len(text)
}

@(private = "file")
expect_lines :: proc(t: ^testing.T, lines, expected: []string) {
	testing.expect_value(t, len(lines), len(expected))
	for line, index in lines {
		if index < len(expected) do testing.expect_value(t, line, expected[index])
	}
}

@(test)
test_wrap_words :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	expect_lines(t, wrap_words("a short text", 20, measure_length), {"a short text"})
	expect_lines(t, wrap_words("one two three four", 9, measure_length), {"one two", "three", "four"})
	expect_lines(t, wrap_words("an overlongword here", 6, measure_length), {"an", "overlongword", "here"})
	expect_lines(t, wrap_words("  ", 6, measure_length), {})
}
