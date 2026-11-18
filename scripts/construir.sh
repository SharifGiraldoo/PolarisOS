#!/usr/bin/env bash
# =============================================================================
# PolarisOS — construye la ISO en tu equipo.
#
# Uso:
#   ./scripts/construir.sh              # en un contenedor Debian 13 (recomendado)
#   ./scripts/construir.sh --nativo     # directo en el equipo (debe ser Debian 13)
#
# Variables opcionales:
#   POLARIS_VERSION=0.2.0 ./scripts/construir.sh
#   LIMPIEZA_TOTAL=1      ./scripts/construir.sh   # vuelve a descargar todo
#
# Resultado: salida/polarisos-<versión>-amd64.iso y salida/SHA256SUMS
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
POLARIS_VERSION="${POLARIS_VERSION:-$(cat "$RAIZ/VERSION")}"
LIMPIEZA_TOTAL="${LIMPIEZA_TOTAL:-0}"

error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- Comprobaciones previas ---------------------------------------------------
[[ "$(uname -m)" == "x86_64" ]] || error "Se necesita un equipo de 64 bits (x86_64)."

libre_gb=$(df -Pk "$RAIZ" | awk 'NR == 2 { print int($4 / 1024 / 1024) }')
(( libre_gb >= 15 )) || error "Hay ${libre_gb} GB libres; se necesitan al menos 15 GB."

# --- Modo nativo --------------------------------------------------------------
if [[ "${1:-}" == "--nativo" ]]; then
	grep -q '^VERSION_CODENAME=trixie' /etc/os-release \
		|| error "El modo nativo requiere un sistema basado en Debian 13 (trixie). Usa el modo contenedor."
	exec sudo env POLARIS_VERSION="$POLARIS_VERSION" LIMPIEZA_TOTAL="$LIMPIEZA_TOTAL" \
		HOST_UID="$(id -u)" HOST_GID="$(id -g)" \
		bash "$RAIZ/scripts/ci-build.sh"
fi

# --- Modo contenedor (por defecto) ---------------------------------------------
# debootstrap necesita crear dispositivos en /dev, algo que un contenedor sin
# root no puede hacer; por eso el contenedor se ejecuta con sudo. El código se
# copia dentro del contenedor y solo la ISO vuelve a tu carpeta salida/.
if command -v podman >/dev/null 2>&1; then
	MOTOR=podman
elif command -v docker >/dev/null 2>&1; then
	MOTOR=docker
else
	error "Instala podman (recomendado) o docker:  sudo apt install podman"
fi

mkdir -p "$RAIZ/salida"
echo "Construyendo PolarisOS ${POLARIS_VERSION} con ${MOTOR}..."
sudo "$MOTOR" run --rm --privileged \
	-v "$RAIZ":/fuente:Z \
	-v polarisos-cache:/trabajo/cache \
	-e POLARIS_VERSION="$POLARIS_VERSION" \
	-e LIMPIEZA_TOTAL="$LIMPIEZA_TOTAL" \
	-e POLARIS_TRABAJO=/trabajo \
	-e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
	docker.io/library/debian:trixie \
	bash /fuente/scripts/ci-build.sh
