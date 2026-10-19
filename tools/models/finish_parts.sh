#!/usr/bin/env bash
# Close and decimate each brief part of a machine's generated model (doc/workflows/models.md, the finish step).
#
#     tools/models/finish_parts.sh <machine> <total> [<total> ...]
#
# parts.py writes each brief part's merged mesh to work/models/<machine>/parts/<part>.ply, reconstruct.py
# closes each by screened Poisson at a cell of CELL metres into <part>_poisson.ply, trimmed of the surface
# farther than TRIM metres from the part, and each total is shared out by the trimmed face counts, at least MINIMUM_TRIANGLES per part. decimate.py brings each closed part to
# its share as <part>_poisson_<total>.glb and mesh_blob.py --keep-frame writes the blob
# data/demos/parts/meshes/<part>_<total>.mesh in the brief's frame. A step whose output exists is skipped,
# so a rerun continues where the last one stopped.
set -euo pipefail

if (( $# < 2 )); then
    echo "usage: tools/models/finish_parts.sh <machine> <total> [<total> ...]" >&2
    exit 1
fi

CELL=0.0025
TRIM=0.01
MINIMUM_TRIANGLES=24

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
machine="$1"
shift
totals=("$@")
parts="$root/work/models/$machine/parts"
meshes="$root/data/demos/parts/meshes"
blender=(flatpak run org.blender.Blender -b --python)

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
    "$root/tools/models/reconstruct.py" "$source" "$output" --technique poisson --cell "$CELL" --trim "$TRIM" > "${output%.ply}.txt"
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

step "$parts" python3 -I "$root/tools/models/parts.py" "$machine" --ply-directory "$parts"

names=()
for ply in "$parts"/*.ply; do
    name="$(basename "$ply" .ply)"
    if [[ "$name" != *_poisson ]]; then
        names+=("$name")
    fi
done

declare -A counts
sum=0
for name in "${names[@]}"; do
    closed="$parts/${name}_poisson.ply"
    step "$closed" close_part "$parts/$name.ply" "$closed"
    counts[$name]="$(face_count "$closed")"
    sum=$(( sum + counts[$name] ))
done

for total in "${totals[@]}"; do
    for name in "${names[@]}"; do
        triangles="$(budget "$total" "${counts[$name]}" "$sum")"
        decimated="$parts/${name}_poisson_${total}.glb"
        blob="$meshes/${name}_${total}.mesh"
        step "$decimated" "${blender[@]}" "$root/tools/models/decimate.py" -- "$parts/${name}_poisson.ply" "$decimated" --triangles "$triangles"
        step "$blob" "$root/tools/models/mesh_blob.py" "$decimated" "$blob" --keep-frame
        log="$parts/${name}_poisson.txt"
        echo "$name: depth $(closed_depth "$log"), $total total, $(untrimmed_count "$log") closed, ${counts[$name]} trimmed, $triangles budget"
    done
done
