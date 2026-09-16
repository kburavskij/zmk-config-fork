SHELL := /bin/bash

.PHONY: help build draw

KEYBOARD ?= $(keyboard)
DONGLE ?= $(dongle)

help:
	@echo "Targets:"
	@echo "  make build KEYBOARD=urchin           Build right/left_central"
	@echo "  make build KEYBOARD=urchin DONGLE=1  Build left_peripheral/right/dongle"
	@echo "  make build KEYBOARD=settings-reset   Build nice!nano settings reset firmware"
	@echo "  make draw KEYBOARD=sweep             Draw Cradio/Sweep and Hyprland maps"

build:
	@if [[ -z "$(KEYBOARD)" ]]; then \
		echo "Usage: make build KEYBOARD=<sweep|urchin|forager> [DONGLE=1]"; \
		exit 1; \
	fi
	tools/build-local-docker.sh "$(KEYBOARD)" $(if $(filter 1,$(DONGLE)),--dongle,)

draw:
	@if [[ "$(KEYBOARD)" != "sweep" && "$(KEYBOARD)" != "cradio" ]]; then \
		echo "Usage: make draw KEYBOARD=sweep"; \
		exit 1; \
	fi
	tools/draw-keymaps-local.sh "$(KEYBOARD)"
