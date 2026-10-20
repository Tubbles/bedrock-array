# 0124: Pivots and sockets as steps

Status: designed (2026-10-20)

Goal: the moving parts and attachment points of the brief as data on the mesh: `pivot {part, axis}` places a part's hinge from the brief's cue (the smelter's lid on its rear top edge, `range_degrees` from the brief), `socket {name, position, direction}` places a named attachment point (the brief's `heat` socket), each shown in the editor as an axis and a marker.

Verify:
- `./build.sh test`; the smelter's lid pivot lies on the lid's rear top edge; shots of the markers.

## Specification

- `Pipeline_Mesh` gains `pivots: [dynamic]Pivot {part, origin, axis, range}` and `sockets: [dynamic]Socket {name, position, direction}`; `pivot` computes the origin and axis from the part's bounds by the brief's axis names (`rear_top_edge` and the like, a table), `socket` takes its position from the step or a stroke placed with the brush.
