// Locks the mouse pointer on a fly page in full screen, so the mouse turns
// without the cursor leaving the canvas. F11 is not the Fullscreen API, so
// a window covering the screen counts as full screen too. Escape releases
// the lock, the browser's own key.
(function () {
	const canvas = document.getElementById("canvas");

	function exports() {
		return window.bedrockMemory.exports;
	}

	function fullScreen() {
		if (document.fullscreenElement) return true;
		return window.innerWidth >= window.screen.width && window.innerHeight >= window.screen.height;
	}

	function locked() {
		return document.pointerLockElement === canvas;
	}

	canvas.addEventListener("pointerdown", function (event) {
		if (event.button !== 0 || !fullScreen() || locked()) return;
		const current = exports();
		if (current && current.pointer_lock_wanted && current.pointer_lock_wanted()) canvas.requestPointerLock();
	});

	// The movement is read here, since the runtime stores it as an integer.
	document.addEventListener("mousemove", function (event) {
		if (!locked()) return;
		const current = exports();
		if (current && current.turn_by_mouse) current.turn_by_mouse(event.movementX, event.movementY);
	});

	window.addEventListener("resize", function () {
		if (locked() && !fullScreen()) document.exitPointerLock();
	});
})();
