#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="zmk-local-keymap-drawer:0.23.0"
WORKSPACE_VOLUME="zmk-draw-cache"
CONTAINER_DRAW_SCRIPT="/zmk-config/tools/docker/draw-in-container.sh"

# shellcheck source=tools/lib/docker-common.sh
source "${REPO_ROOT}/tools/lib/docker-common.sh"

build_draw_image_if_missing() {
	if "${CONTAINER_CMD}" image inspect "${IMAGE}" >/dev/null 2>&1; then
		return
	fi

	echo "Building local keymap-drawer image: ${IMAGE}"
	"${CONTAINER_CMD}" build \
		-t "${IMAGE}" \
		-f "${REPO_ROOT}/tools/docker/Dockerfile.keymap-drawer" \
		"${REPO_ROOT}"
}

if [[ $# -ne 1 ]]; then
	echo "Usage: tools/draw-keymaps-local.sh sweep" >&2
	exit 1
fi

if [[ "$1" != "sweep" && "$1" != "cradio" ]]; then
	echo "Usage: tools/draw-keymaps-local.sh sweep" >&2
	exit 1
fi

keyboard="cradio"

keymap_path="config/${keyboard}.keymap"
if [[ ! -f "${REPO_ROOT}/${keymap_path}" ]]; then
	echo "Keymap not found: ${keyboard}" >&2
	exit 1
fi

ensure_docker
build_draw_image_if_missing

"${CONTAINER_CMD}" run --rm \
	-v "${REPO_ROOT}:/zmk-config:Z" \
	-v "${WORKSPACE_VOLUME}:/work:Z" \
	"${IMAGE}" \
	/bin/bash "${CONTAINER_DRAW_SCRIPT}" "${keymap_path}"

echo "Done. Generated files are in tools/keymap-drawer"
echo "- tools/keymap-drawer/${keyboard}.yaml"
echo "- tools/keymap-drawer/${keyboard}.svg"
if [[ -f "${REPO_ROOT}/tools/keymap-drawer/${keyboard}-hyprland.svg" ]]; then
	echo "- tools/keymap-drawer/${keyboard}-hyprland.svg"
fi
