// Runs the demo and keeps one plaque per scene label over its projected
// point, and on a scene that names more than one configuration a button
// showing the current one that cycles it. The Odin runtime has no DOM
// writer, so the plaques and the button live here.
(function () {
	const memory = new odin.WasmMemoryInterface();
	const plaques = [];
	let created = false;
	let button = null;

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

	function refreshButton(exports) {
		const name = memory.loadString(exports.configuration_name_pointer(), exports.configuration_name_length());
		if (button.textContent !== name) button.textContent = name;
	}

	function createButton(exports) {
		if (exports.configuration_count() <= 1) return;
		button = document.createElement("button");
		button.className = "configuration";
		button.addEventListener("click", function () {
			exports.cycle_configuration();
			refreshButton(exports);
			// A focused button would also take Space, the rise key.
			button.blur();
		});
		document.body.appendChild(button);
	}

	function frame() {
		const exports = memory.exports;
		if (exports && exports.label_count) {
			if (!created) {
				createPlaques(exports);
				createButton(exports);
			}
			placePlaques(exports);
			if (button) refreshButton(exports);
		}
		window.requestAnimationFrame(frame);
	}

	// runWasm registers the demo's step before it resolves, so a frame
	// started after it runs after the step and the plaques never trail.
	odin.runWasm("demo.wasm", null, undefined, memory).then(function () {
		window.requestAnimationFrame(frame);
	});
})();
