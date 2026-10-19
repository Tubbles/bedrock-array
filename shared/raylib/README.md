# raylib binding and library

The Odin binding for raylib 6.0 with a raylib built from source, used through the `shared` collection (`build.sh` passes `-collection:shared=shared`, the app imports `shared:raylib` and `shared:raylib/rlgl`). Carried from Mine oh Belowed (its work items 0085 and 0104), desktop Linux only.

Why a copy: the binding names its library by a path next to itself (`linux/libraylib.a`, and `../linux/libraylib.a` in `rlgl`), so no linker flag can swap in another archive. The toolchain under `~/opt/odin` stays untouched.

- `raylib.odin`, `raymath.odin`, `rlgl/rlgl.odin`, `LICENSE`: copied unchanged from `vendor/raylib/` of Odin release dev-2026-09 (nightly a2fb372). `easings.odin` and `raygui.odin` (which needs its own `libraygui.a`) are not copied.
- `platform.odin`: ours. Declares GLFW's `glfwGetPlatform`, `glfwGetCurrentContext`, `glfwGetWindowSize` and `glfwGetProcAddress` from the same archive, which the binding does not expose. The last one is how the app loads `vendor:OpenGL` without linking libGL.
- `linux/libraylib.a`: the archive Mine oh Belowed's `tools/build_raylib.sh` wrote (its build record below), GLFW with both the Wayland and the X11 backend, the same bytes. Rebuilt here by `tools/build_raylib.sh`. It is committed, so a checkout builds without cmake or a container.

After an Odin upgrade: copy the four files from the new `vendor/raylib/` again, check the raylib version it binds, and when the version changed set `raylib_tag` in `tools/build_raylib.sh` and rerun it.

## Build record

Rewritten by `tools/build_raylib.sh` from its marker to the end.

<!-- build record -->
- raylib tag: 6.0 (https://github.com/raysan5/raylib), commit dbc56a87da87d973a9c5baa4e7438a9d20121d28
- cmake flags: -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DPLATFORM=Desktop -DGLFW_BUILD_WAYLAND=ON -DGLFW_BUILD_X11=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
- compiler: cc (GCC) 16.2.1 20260819 (Red Hat 16.2.1-2)
- built: 2026-09-28T16:24Z
- archive: linux/libraylib.a, 3390886 bytes
