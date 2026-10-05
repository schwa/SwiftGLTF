default:
    just --list

download-sample-assets:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d .sample-assets ]; then
    	git clone --depth 1 https://github.com/KhronosGroup/glTF-Sample-Assets.git .sample-assets
    else
    	git -C .sample-assets pull --ff-only
    fi
