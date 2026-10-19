package app

import "core:strings"

// Greedy: words joined by single spaces while the line measures within the
// maximum. A word that alone exceeds the maximum stands on its own line.
wrap_words :: proc(text: string, maximum_width: int, measure: proc(text: string) -> int, allocator := context.temp_allocator) -> []string {
	lines := make([dynamic]string, allocator)
	line := ""
	words := text
	for word in strings.fields_iterator(&words) {
		candidate := word if line == "" else strings.concatenate({line, " ", word}, allocator)
		if line != "" && measure(candidate) > maximum_width {
			append(&lines, line)
			candidate = word
		}
		line = candidate
	}
	if line != "" do append(&lines, line)
	return lines[:]
}
