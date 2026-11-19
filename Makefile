# =============================================================================
# PolarisOS — atajos para las tareas más comunes.  Escribe `make` para ver la ayuda.
# =============================================================================
VERSION ?= $(shell cat VERSION)
EDICION ?= estandar
export POLARIS_VERSION := $(VERSION)
export POLARIS_EDICION := $(EDICION)

.DEFAULT_GOAL := ayuda
.PHONY: ayuda iso iso-todas iso-nativo paquetes prueba-humo arte revisar probar-bios probar-uefi probar-secureboot \
        instalar-prueba arrancar-instalado limpiar

ayuda: ## Muestra esta ayuda
	@echo "PolarisOS $(VERSION) — tareas disponibles:"
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN { FS = ":.*## " } { printf "  make %-20s %s\n", $$1, $$2 }'
	@echo
	@echo "Ejemplos: make iso   ·   make iso EDICION=edu   ·   make iso EDICION=maker"

iso: ## Construye la ISO en un contenedor Debian 13 (EDICION=estandar|edu|maker)
	./scripts/construir.sh

iso-todas: ## Construye las tres ediciones (estándar, Edu y Maker)
	$(MAKE) iso EDICION=estandar
	$(MAKE) iso EDICION=edu
	$(MAKE) iso EDICION=maker

paquetes: ## Construye solo los paquetes .deb de PolarisOS en salida/paquetes
	./scripts/construir-paquetes.sh salida/paquetes

prueba-humo: ## Arranca la ISO sin pantalla y comprueba que llega al escritorio
	./scripts/prueba-humo.sh

iso-nativo: ## Construye la ISO directamente en un sistema Debian 13
	./scripts/construir.sh --nativo

arte: ## Regenera logo, fondo e imágenes del instalador (requiere python3-pil)
	python3 assets/generar-arte.py

revisar: ## Revisa los scripts (shellcheck) y el código Python
	LC_ALL=C.UTF-8 shellcheck -x auto/* scripts/*.sh config/hooks/normal/*.hook.* \
		ediciones/*/hooks/normal/*.hook.* \
		packages/polaris-branding/files/polaris-first-login \
		packages/polaris-branding/files/polaris-check \
		packages/polaris-branding/files/polaris-bluetooth-applet \
		packages/polaris-welcome/files/polaris-update-notifier \
		packages/polaris-welcome/files/polaris-a11y \
		$(wildcard packages/*/debian/preinst packages/*/debian/postinst) \
		$(wildcard packages/*/debian/prerm packages/*/debian/postrm)
	python3 -m py_compile packages/polaris-welcome/files/polaris-welcome \
		scripts/generar-sbom.py assets/generar-arte.py

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
	@if [ -d .trabajo ]; then \
		echo "Quedan restos de una construcción nativa: ejecuta 'sudo rm -rf .trabajo'"; \
	fi
