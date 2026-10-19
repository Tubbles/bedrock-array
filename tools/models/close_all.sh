#!/usr/bin/env bash
# Make the closed variants of the smelter's models for the models page (doc/workflows/models.md, step 1).
#
#     tools/models/close_all.sh [--dry-run]
#
# For each technique and each line of the table: the closed mesh of the source under
# work/models/smelter/closed/, decimated to the line's count, then the blob under
# data/demos/models/meshes/<blob>_<technique>.mesh. A step whose output exists is skipped, so a rerun
# continues where the last one stopped. --dry-run prints the commands instead of running them.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sources="$root/work/models/smelter"
closed="$sources/closed"
meshes="$root/data/demos/models/meshes"
techniques=(fill voxel poisson alphawrap)
table=(
    "model_7_faces24000.glb|20824|faces24000"
    "model_7_faces12000.glb|10700|faces12000"
    "model_7_faces20000_smart.glb|29476|faces20000_smart"
    "model_7_smart.glb|10796|smart"
    "model_7_faces12000_smart.glb|10409|faces12000_smart"
    "model_7.glb|24000|blender_full_24000"
    "model_7.glb|10700|blender_full_10700"
    "model_7_faces700000.glb|24000|blender_700000_24000"
    "model_7_faces700000.glb|10700|blender_700000_10700"
)

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=true
fi

declare -A made

blender=(flatpak run org.blender.Blender -b --python)

# Runs or prints the command that makes the output, unless the output exists already.
step() {
    local output="$1"
    shift
    if [[ -e "$output" || -n "${made[$output]:-}" ]]; then
        return
    fi
    made[$output]=1
    if $dry_run; then
        echo "$*"
    else
        "$@"
    fi
}

close() {
    local technique="$1" source="$2" output="$3"
    case "$technique" in
        fill | voxel) step "$output" "${blender[@]}" "$root/tools/models/close.py" -- "$source" "$output" --technique "$technique" ;;
        *) step "$output" "$root/tools/models/reconstruct.py" "$source" "$output" --technique "$technique" ;;
    esac
}

closed_extension() {
    case "$1" in
        fill | voxel) echo glb ;;
        *) echo ply ;;
    esac
}

if ! $dry_run; then
    mkdir -p "$closed"
fi
for technique in "${techniques[@]}"; do
    for line in "${table[@]}"; do
        IFS="|" read -r source count blob <<< "$line"
        model="${source%.glb}"
        closed_mesh="$closed/${model}_${technique}.$(closed_extension "$technique")"
        decimated="$closed/${model}_${technique}_decimated${count}.glb"
        close "$technique" "$sources/$source" "$closed_mesh"
        step "$decimated" "${blender[@]}" "$root/tools/models/decimate.py" -- "$closed_mesh" "$decimated" --triangles "$count"
        step "$meshes/${blob}_${technique}.mesh" "$root/tools/models/mesh_blob.py" "$decimated" "$meshes/${blob}_${technique}.mesh" --height 1
    done
done
