// Runs the demo and keeps one plaque per scene label over its projected
// point. The Odin runtime has no DOM writer, so the plaques live here.
(function () {
	const memory = new odin.WasmMemoryInterface();
	const plaques = [];
	let created = false;

	function createPlaques(exports) {
		const count = exports.label_count();
		for (let index = 0; index < count; index += 1) {
			const plaque = document.createElement("div");
			plaque.className = "label";
			plaque.textContent = memory.loadString(exports.label_text_pointer(index), exports.label_text_length(index));
			document.body.appendChild(plaque);
			plaques.push(plaque);
		}
		created = true;
	}

	function placePlaques(exports) {
		plaques.forEach(function (plaque, index) {
			plaque.style.left = exports.label_screen_x(index) + "px";
			plaque.style.top = exports.label_screen_y(index) + "px";
			plaque.style.visibility = exports.label_visible(index) ? "visible" : "hidden";
		});
	}

	function frame() {
		const exports = memory.exports;
		if (exports && exports.label_count) {
			if (!created) createPlaques(exports);
			placePlaques(exports);
		}
		window.requestAnimationFrame(frame);
	}

	// runWasm registers the demo's step before it resolves, so a frame
	// started after it runs after the step and the plaques never trail.
	odin.runWasm("demo.wasm", null, undefined, memory).then(function () {
		window.requestAnimationFrame(frame);
	});
})();
