# =============================================================================
# PolarisOS — atajos para las tareas más comunes.  Escribe `make` para ver la ayuda.
# =============================================================================
VERSION ?= $(shell cat VERSION)
export POLARIS_VERSION := $(VERSION)

.DEFAULT_GOAL := ayuda
.PHONY: ayuda iso iso-nativo arte revisar probar-bios probar-uefi probar-secureboot \
        instalar-prueba arrancar-instalado limpiar

ayuda: ## Muestra esta ayuda
	@echo "PolarisOS $(VERSION) — tareas disponibles:"
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN { FS = ":.*## " } { printf "  make %-20s %s\n", $$1, $$2 }'
	@echo
	@echo "Ejemplo: make iso VERSION=0.2.0"

iso: ## Construye la ISO en un contenedor Debian 13 (recomendado)
	./scripts/construir.sh

iso-nativo: ## Construye la ISO directamente en un sistema Debian 13
	./scripts/construir.sh --nativo

arte: ## Regenera logo, fondo e imágenes del instalador (requiere python3-pil)
	python3 assets/generar-arte.py

revisar: ## Revisa los scripts con shellcheck
	shellcheck -x auto/* scripts/*.sh config/hooks/normal/*.hook.* \
		packages/polaris-branding/files/polaris-first-login packages/polaris-branding/files/polaris-check packages/polaris-branding/files/polaris-bluetooth-applet \
		packages/polaris-branding/debian/preinst packages/polaris-branding/debian/postrm

probar-bios: ## Prueba la ISO en QEMU con arranque BIOS y 2 GB de RAM
	./scripts/probar-qemu.sh bios

probar-uefi: ## Prueba la ISO en QEMU con arranque UEFI y 2 GB de RAM
	./scripts/probar-qemu.sh uefi

probar-secureboot: ## Prueba la ISO en QEMU con Secure Boot activo
	./scripts/probar-qemu.sh secureboot

instalar-prueba: ## Arranca la ISO con un disco virtual para probar Calamares
	./scripts/probar-qemu.sh uefi --disco

arrancar-instalado: ## Arranca el sistema instalado en el disco virtual
	./scripts/probar-qemu.sh uefi --solo-disco

limpiar: ## Borra salida/ y los restos de live-build
	rm -rf salida
	@if [ -d chroot ] || [ -d binary ] || [ -d cache ]; then \
		echo "Quedan restos de una construcción nativa: ejecuta 'sudo lb clean --purge'"; \
	fi
