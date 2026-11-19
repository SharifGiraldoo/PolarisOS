#!/usr/bin/env bash
# =============================================================================
# PolarisOS — construye los paquetes propios de packages/*/ (.deb).
#
# Uso:   scripts/construir-paquetes.sh [DESTINO]
#        DESTINO por defecto: config/packages.chroot
#
# Lo usan ci-build.sh (para meter los paquetes en la ISO) y el workflow del
# repositorio APT (para publicarlos y que los sistemas instalados se actualicen).
#
# polaris-archive-keyring solo se construye si existe la llave pública del
# repositorio en repo/polarisos-archive-keyring.asc (ver docs/GUIA.md).
# Requiere: dpkg-dev, debhelper, fakeroot y gnupg.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="$(realpath -m "${1:-$RAIZ/config/packages.chroot}")"
mkdir -p "$DESTINO"

for dir in "$RAIZ"/packages/*/; do
	nombre="$(basename "$dir")"

	if [[ "$nombre" == "polaris-archive-keyring" && ! -f "$RAIZ/repo/polarisos-archive-keyring.asc" ]]; then
		echo "Omitiendo $nombre: falta repo/polarisos-archive-keyring.asc"
		continue
	fi

	echo "Construyendo $nombre..."
	(cd "$dir" && dpkg-buildpackage -us -uc -b -d)

	rm -f "$DESTINO/${nombre}"_*.deb
	mv "$RAIZ"/packages/"${nombre}"_*.deb "$DESTINO/"
	rm -f "$RAIZ"/packages/"${nombre}"_*.buildinfo "$RAIZ"/packages/"${nombre}"_*.changes
	(cd "$dir" && rm -rf "debian/$nombre" debian/.debhelper debian/files \
		debian/debhelper-build-stamp debian/*.substvars)
done

echo "Paquetes listos en $DESTINO:"
ls -1 "$DESTINO"/*.deb
