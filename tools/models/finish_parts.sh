#!/usr/bin/env bash
# Close and decimate each brief part of a machine's generated model (doc/workflows/models.md, the finish step).
#
#     tools/models/finish_parts.sh <machine> --trim <metres> <total> [<total> ...]
#
# parts.py writes each brief part's merged mesh to work/models/<machine>/parts/<part>.ply. A part whose
# closing in generated.sjson is poisson is closed by reconstruct.py, screened Poisson at a cell of CELL
# metres trimmed of the surface farther than the trim from the part, into <part>_poisson_trim<mm>.ply. A
# part closed none keeps its raw mesh. Each total is shared out by these face counts, at least
# MINIMUM_TRIANGLES per part, decimate.py brings each part to its share as <part>_<closing>_trim<mm>_<total>.glb
# and mesh_blob.py --keep-frame writes the blob data/demos/parts/meshes/<part>_<total>_trim<mm>.mesh in the
# brief's frame. A none part's blob carries the trim too, since its share depends on the others, so each
# trim's run is complete on its own. A step whose output exists is skipped, so a rerun continues where the
# last one stopped.
set -euo pipefail

usage() {
    echo "usage: tools/models/finish_parts.sh <machine> --trim <metres> <total> [<total> ...]" >&2
    exit 1
}

if (( $# < 4 )) || [[ "$2" != "--trim" ]]; then
    usage
fi

CELL=0.0025
MINIMUM_TRIANGLES=24

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
machine="$1"
trim="$3"
shift 3
totals=("$@")
parts="$root/work/models/$machine/parts"
meshes="$root/data/demos/parts/meshes"
blender=(flatpak run org.blender.Blender -b --python)
millimetres="$(awk -v metres="$trim" 'BEGIN { printf "%d", metres * 1000 + 0.5 }')"

# Runs the command that makes the output, unless the output exists already.
step() {
    local output="$1"
    shift
    if [[ -e "$output" ]]; then
        return
    fi
    "$@"
}

# Closes a part and keeps reconstruct.py's printed lines beside the closed mesh, for the depth.
close_part() {
    local source="$1" output="$2"
    "$root/tools/models/reconstruct.py" "$source" "$output" --technique poisson --cell "$CELL" --trim "$trim" > "${output%.ply}.txt"
}

# Prints the face count from a PLY header.
face_count() {
    LC_ALL=C sed -n '/^element face /{s/^element face //p;q}' "$1"
}

# Prints the depth reconstruct.py chose for a closed part.
closed_depth() {
    LC_ALL=C sed -n 's/^depth \([0-9]*\) .*/\1/p' "$1"
}

# Prints the face count Poisson made for a part before the trim.
untrimmed_count() {
    LC_ALL=C sed -n 's/^reconstructed [0-9]* to \([0-9]*\) faces.*/\1/p' "$1"
}

# Prints max(minimum, round(total * count / sum)) in integer arithmetic.
budget() {
    local total="$1" count="$2" sum="$3"
    local share=$(( (2 * total * count + sum) / (2 * sum) ))
    echo $(( share > MINIMUM_TRIANGLES ? share : MINIMUM_TRIANGLES ))
}

# Prints the mesh a part is decimated from: its closed mesh, or its raw mesh when it is closed none.
source_mesh() {
    local name="$1" closing="$2"
    if [[ "$closing" == "poisson" ]]; then
        echo "$parts/${name}_poisson_trim${millimetres}.ply"
    else
        echo "$parts/$name.ply"
    fi
}

# Prints the closing's part of a summary line.
closing_summary() {
    local name="$1" closing="$2" count="$3"
    if [[ "$closing" == "poisson" ]]; then
        local log="$parts/${name}_poisson_trim${millimetres}.txt"
        echo "depth $(closed_depth "$log"), $(untrimmed_count "$log") closed, $count trimmed"
    else
        echo "not closed, $count raw"
    fi
}

step "$parts" python3 -I "$root/tools/models/parts.py" "$machine" --ply-directory "$parts"

names=()
declare -A closings
while read -r name closing; do
    names+=("$name")
    closings[$name]="$closing"
done < <(python3 -I "$root/tools/models/parts.py" "$machine" --closings)

declare -A counts
sum=0
for name in "${names[@]}"; do
    mesh="$(source_mesh "$name" "${closings[$name]}")"
    if [[ "${closings[$name]}" == "poisson" ]]; then
        step "$mesh" close_part "$parts/$name.ply" "$mesh"
    fi
    counts[$name]="$(face_count "$mesh")"
    sum=$(( sum + counts[$name] ))
done

for total in "${totals[@]}"; do
    for name in "${names[@]}"; do
        closing="${closings[$name]}"
        triangles="$(budget "$total" "${counts[$name]}" "$sum")"
        decimated="$parts/${name}_${closing}_trim${millimetres}_${total}.glb"
        blob="$meshes/${name}_${total}_trim${millimetres}.mesh"
        step "$decimated" "${blender[@]}" "$root/tools/models/decimate.py" -- "$(source_mesh "$name" "$closing")" "$decimated" --triangles "$triangles"
        step "$blob" "$root/tools/models/mesh_blob.py" "$decimated" "$blob" --keep-frame
        echo "$name: $(closing_summary "$name" "$closing" "${counts[$name]}"), $total total, $triangles budget"
    done
done
