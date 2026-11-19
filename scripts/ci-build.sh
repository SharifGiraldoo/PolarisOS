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
#   POLARIS_EDICION   estandar (por defecto), edu o maker
#   POLARIS_ARCH      amd64 o arm64 (por defecto, la del equipo)
#   POLARIS_TRABAJO   directorio donde se copia el código y se construye
#                     (por defecto <repo>/.trabajo). Así los archivos de root
#                     del chroot no se mezclan con tu repositorio. La ISO
#                     siempre termina en <repo>/salida/.
#   LIMPIEZA_TOTAL=1  borra también la caché de paquetes descargados
#   HOST_UID/HOST_GID devuelve la propiedad de salida/ a tu usuario
# =============================================================================
set -euo pipefail

FUENTE="$(cd "$(dirname "$0")/.." && pwd)"
POLARIS_VERSION="${POLARIS_VERSION:-$(cat "$FUENTE/VERSION")}"
POLARIS_EDICION="${POLARIS_EDICION:-estandar}"
POLARIS_ARCH="${POLARIS_ARCH:-$(dpkg --print-architecture)}"
POLARIS_TRABAJO="${POLARIS_TRABAJO:-$FUENTE/.trabajo}"
export POLARIS_VERSION POLARIS_EDICION POLARIS_ARCH DEBIAN_FRONTEND=noninteractive

paso() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

if [[ "$POLARIS_EDICION" != "estandar" && ! -d "$FUENTE/ediciones/$POLARIS_EDICION" ]]; then
	echo "ERROR: no existe la edición '$POLARIS_EDICION' en ediciones/" >&2
	exit 1
fi

paso "1/6 Instalando herramientas de construcción"
apt-get update -q
apt-get install -y -q --no-install-recommends \
	live-build debootstrap squashfs-tools xorriso mtools dosfstools \
	ca-certificates build-essential debhelper dpkg-dev fakeroot apt-utils wget gnupg

paso "2/6 Preparando el directorio de trabajo (edición: $POLARIS_EDICION, $POLARIS_ARCH)"
mkdir -p "$POLARIS_TRABAJO"
# Se borra la configuración de la construcción anterior, pero no cache/
find "$POLARIS_TRABAJO" -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf {} +
tar -C "$FUENTE" \
	--exclude=./.git --exclude=./salida --exclude=./cache --exclude=./.trabajo \
	--exclude=./chroot --exclude=./binary --exclude=./.build \
	-cf - . | tar -C "$POLARIS_TRABAJO" -xf -
cd "$POLARIS_TRABAJO"

# Las ediciones agregan sus listas de paquetes, hooks y archivos encima de config/
if [[ "$POLARIS_EDICION" != "estandar" ]]; then
	cp -a "ediciones/$POLARIS_EDICION/." config/
	echo "Edición $POLARIS_EDICION aplicada sobre config/"
fi
echo "Construyendo en: $(pwd)"

paso "3/6 Construyendo los paquetes de PolarisOS"
bash scripts/construir-paquetes.sh config/packages.chroot
# El repositorio APT propio solo se configura si su llave ya existe
if ls config/packages.chroot/polaris-archive-keyring_*.deb >/dev/null 2>&1; then
	printf '# Generado por ci-build.sh\npolaris-archive-keyring\n' \
		> config/package-lists/09-polaris-repo.list.chroot
fi

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

# live-build nombra la imagen "<nombre>-<arch>.hybrid.iso". El formato sigue
# siendo híbrido (arranca desde DVD y desde USB), pero el archivo se publica
# con un nombre limpio: polarisos-<versión>-<arch>.iso
for iso in ./*.hybrid.iso; do
	[ -e "$iso" ] && mv -f "$iso" "${iso%.hybrid.iso}.iso"
done

mkdir -p "$FUENTE/salida"
mv -f ./*.iso "$FUENTE/salida/"
# Lista de paquetes de la imagen (manifiesto), usada para el SBOM
for lista in ./*.packages; do
	[ -e "$lista" ] && cp -f "$lista" "$FUENTE/salida/$(basename "${lista%.hybrid.packages}" .packages).packages"
done
cp -f build.log "$FUENTE/salida/build-${POLARIS_EDICION}-${POLARIS_VERSION}-${POLARIS_ARCH}.log"
(cd "$FUENTE/salida" && sha256sum -- *.iso > SHA256SUMS)

if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
	chown -R "${HOST_UID}:${HOST_GID}" "$FUENTE/salida"
fi

paso "Listo"
ls -lh "$FUENTE/salida/"
