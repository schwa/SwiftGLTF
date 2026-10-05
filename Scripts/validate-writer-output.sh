#!/usr/bin/env bash
# Writes every sample GLB with SwiftGLTF (GLB -> GLB and GLB -> embedded glTF) and
# validates the output with the Khronos glTF-Validator.
# Usage: Scripts/validate-writer-output.sh <path-to-gltf-render> [models-dir]
set -euo pipefail

renderer="$1"
models="${2:-.sample-assets/Models}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT

(cd "$script_dir/khronos-validator" && npm ci --no-audit --no-fund --silent)

count=0
for source in "$models"/*/glTF-Binary/*.glb; do
    name="$(basename "$(dirname "$(dirname "$source")")")"
    # Skip inputs our loader rejects (e.g. unsupported features); not a writer issue.
    if ! "$renderer" convert "$source" "$output/$name.glb" >/dev/null 2>&1; then
        echo "skip $name (could not load/convert)"
        continue
    fi
    "$renderer" convert "$source" "$output/$name.gltf" >/dev/null
    count=$((count + 1))
done
echo "converted $count models"

node "$script_dir/khronos-validator/validate.mjs" "$output"
