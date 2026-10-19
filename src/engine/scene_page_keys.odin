package engine

// A walk direction held on the keyboard.
Scene_Page_Key :: enum {
	Forward,
	Back,
	Left,
	Right,
	Up,
	Down,
}

scene_page_key_from_code :: proc(code: string) -> (Scene_Page_Key, bool) {
	switch code {
	case "KeyW", "ArrowUp":
		return .Forward, true
	case "KeyS", "ArrowDown":
		return .Back, true
	case "KeyA", "ArrowLeft":
		return .Left, true
	case "KeyD", "ArrowRight":
		return .Right, true
	case "KeyE", "Space":
		return .Up, true
	case "KeyQ", "ShiftLeft", "ShiftRight":
		return .Down, true
	}
	return .Forward, false
}
