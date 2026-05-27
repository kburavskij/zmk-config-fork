#!/usr/bin/env bash

ensure_docker() {
	# Check for podman first, then docker
	if command -v podman >/dev/null 2>&1; then
		CONTAINER_CMD="podman"
	elif command -v docker >/dev/null 2>&1; then
		CONTAINER_CMD="docker"
	else
		echo "Neither Podman nor Docker is installed. Install one of them first." >&2
		exit 1
	fi

	# Only check daemon status for docker (podman doesn't need a daemon)
	if [[ "${CONTAINER_CMD}" == "docker" ]]; then
		if ! docker info >/dev/null 2>&1; then
			echo "Docker daemon is not running. Start Docker Desktop and try again." >&2
			exit 1
		fi
	fi
}
