#!/usr/bin/env bash
# =============================================================================
# PolarisOS — construcción completa DENTRO de un contenedor Debian 13.
#
# La usan tanto `scripts/construir.sh` (en tu equipo) como GitHub Actions,
# así que lo que compila en tu equipo compila igual en la nube.
#
# Requiere root y, si corre en contenedor, que sea --privileged.
#
# Variables:
#   POLARIS_VERSION   versión de la ISO (por defecto, el archivo VERSION)
#   POLARIS_TRABAJO   si se define, copia el código a ese directorio y construye
#                     allí (así los archivos de root del chroot no quedan en tu
#                     repositorio). La ISO siempre termina en <repo>/salida/.
#   LIMPIEZA_TOTAL=1  borra también la caché de paquetes descargados
#   HOST_UID/HOST_GID devuelve la propiedad de salida/ a tu usuario
# =============================================================================
set -euo pipefail

FUENTE="$(cd "$(dirname "$0")/.." && pwd)"
POLARIS_VERSION="${POLARIS_VERSION:-$(cat "$FUENTE/VERSION")}"
export POLARIS_VERSION DEBIAN_FRONTEND=noninteractive

paso() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

paso "1/6 Instalando herramientas de construcción"
apt-get update -q
apt-get install -y -q --no-install-recommends \
	live-build debootstrap squashfs-tools xorriso mtools dosfstools \
	ca-certificates build-essential debhelper dpkg-dev fakeroot apt-utils wget

paso "2/6 Preparando el directorio de trabajo"
if [[ -n "${POLARIS_TRABAJO:-}" ]]; then
	mkdir -p "$POLARIS_TRABAJO"
	tar -C "$FUENTE" \
		--exclude=./.git --exclude=./salida --exclude=./cache \
		--exclude=./chroot --exclude=./binary --exclude=./.build \
		-cf - . | tar -C "$POLARIS_TRABAJO" -xf -
	cd "$POLARIS_TRABAJO"
else
	cd "$FUENTE"
fi
echo "Construyendo en: $(pwd)"

paso "3/6 Construyendo el paquete polaris-branding"
(cd packages/polaris-branding && dpkg-buildpackage -us -uc -b -d)
mkdir -p config/packages.chroot
rm -f config/packages.chroot/polaris-branding_*.deb
cp packages/polaris-branding_*_all.deb config/packages.chroot/
rm -f packages/*.deb packages/*.buildinfo packages/*.changes
(cd packages/polaris-branding && rm -rf debian/polaris-branding debian/.debhelper \
	debian/files debian/debhelper-build-stamp debian/*.substvars)

paso "4/6 Limpiando construcciones anteriores"
if [[ "${LIMPIEZA_TOTAL:-0}" == "1" ]]; then
	lb clean --purge
else
	lb clean          # conserva cache/ para no descargar todo otra vez
fi

paso "5/6 Configurando live-build (PolarisOS ${POLARIS_VERSION})"
lb config

paso "6/6 Construyendo la ISO (puede tardar 20-60 minutos)"
lb build

# live-build nombra la imagen "<nombre>-amd64.hybrid.iso". El formato sigue
# siendo híbrido (arranca desde DVD y desde USB), pero el archivo se publica
# con un nombre limpio: polarisos-<versión>-amd64.iso
for iso in ./*.hybrid.iso; do
	[ -e "$iso" ] && mv -f "$iso" "${iso%.hybrid.iso}.iso"
done

mkdir -p "$FUENTE/salida"
mv -f ./*.iso "$FUENTE/salida/"
cp -f build.log "$FUENTE/salida/build-${POLARIS_VERSION}.log"
(cd "$FUENTE/salida" && sha256sum -- *.iso > SHA256SUMS)

if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
	chown -R "${HOST_UID}:${HOST_GID}" "$FUENTE/salida"
fi

paso "Listo"
ls -lh "$FUENTE/salida/"
