#!/usr/bin/env bash
# =============================================================================
# PolarisOS — prueba de humo: arranca la ISO en QEMU sin pantalla y comprueba
# que el sistema llega al escritorio. Guarda una captura y el registro.
#
# Uso:   scripts/prueba-humo.sh [ISO]
#        (sin argumento usa la ISO amd64 más reciente de salida/)
#
# Variables:  RAM=2048  TIEMPO_MAX=900 (segundos)  SALIDA=salida/prueba-humo
# Requiere:   qemu-system-x86 y xorriso; ImageMagick (opcional) para el PNG.
#
# El kernel se arranca directamente (sin el menú GRUB) con console=ttyS0 para
# poder leer los mensajes de systemd por el puerto serie.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:-$(find "$RAIZ/salida" -maxdepth 1 -name '*-amd64.iso' -printf '%T@ %p\n' 2>/dev/null \
	| sort -rn | head -n 1 | cut -d' ' -f2-)}"
RAM="${RAM:-2048}"
TIEMPO_MAX="${TIEMPO_MAX:-900}"
SALIDA="$(realpath -m "${SALIDA:-$RAIZ/salida/prueba-humo}")"

error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
[[ -n "$ISO" && -f "$ISO" ]] || error "No encontré la ISO (pásala como argumento)."
command -v qemu-system-x86_64 >/dev/null || error "Falta qemu-system-x86"
command -v xorriso >/dev/null || error "Falta xorriso"

TMP="$(mktemp -d)"
mkdir -p "$SALIDA"
SERIE="$SALIDA/serie.log"
: > "$SERIE"

limpiar() {
	if [[ -f "$TMP/qemu.pid" ]]; then
		kill "$(cat "$TMP/qemu.pid")" 2>/dev/null || true
	fi
	rm -rf "$TMP"
}
trap limpiar EXIT

echo "Extrayendo el kernel y el initrd de $(basename "$ISO")..."
xorriso -osirrox on -indev "$ISO" \
	-extract /live/vmlinuz "$TMP/vmlinuz" \
	-extract /live/initrd.img "$TMP/initrd.img" >/dev/null 2>&1 \
	|| error "No pude extraer /live/vmlinuz e /live/initrd.img de la ISO"

PARAMETROS="boot=live components username=polaris user-fullname=PolarisOS hostname=polarisos"
PARAMETROS+=" locales=en_US.UTF-8 keyboard-layouts=us timezone=Etc/UTC"
PARAMETROS+=" console=ttyS0,115200 systemd.show_status=1"

ACELERACION=(-cpu max)
if [[ -w /dev/kvm ]]; then
	ACELERACION=(-enable-kvm -cpu host)
else
	echo "Aviso: sin KVM, la prueba será lenta."
fi

echo "Arrancando PolarisOS con ${RAM} MB de RAM..."
qemu-system-x86_64 -m "$RAM" -smp 2 "${ACELERACION[@]}" \
	-cdrom "$ISO" -kernel "$TMP/vmlinuz" -initrd "$TMP/initrd.img" -append "$PARAMETROS" \
	-vga virtio -display none -nic "user,model=virtio-net-pci" \
	-serial "file:$SERIE" \
	-monitor "unix:$TMP/monitor.sock,server,nowait" \
	-daemonize -pidfile "$TMP/qemu.pid"

INICIO=$SECONDS
ESTADO="tiempo agotado"
while (( SECONDS - INICIO < TIEMPO_MAX )); do
	if grep -q 'Kernel panic' "$SERIE"; then
		ESTADO="kernel panic"
		break
	fi
	if grep -Eq 'Started (lightdm\.service|.*Light Display Manager)' "$SERIE"; then
		ESTADO="ok"
		break
	fi
	sleep 5
done
DURACION=$(( SECONDS - INICIO ))

if [[ "$ESTADO" == "ok" ]]; then
	echo "LightDM arrancó en ${DURACION} s. Esperando el escritorio para la captura..."
	sleep 90
	python3 - "$TMP/monitor.sock" "$TMP/pantalla.ppm" <<'EOF'
import socket, sys, time
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(sys.argv[1])
time.sleep(0.5)
sock.sendall(f"screendump {sys.argv[2]}\n".encode())
time.sleep(3)
sock.close()
EOF
	if [[ -f "$TMP/pantalla.ppm" ]]; then
		if command -v convert >/dev/null; then
			convert "$TMP/pantalla.ppm" "$SALIDA/escritorio.png"
		else
			cp "$TMP/pantalla.ppm" "$SALIDA/escritorio.ppm"
		fi
	fi
fi

{
	echo "ISO:       $(basename "$ISO")"
	echo "RAM:       ${RAM} MB"
	echo "Resultado: ${ESTADO}"
	echo "Tiempo:    ${DURACION} s hasta LightDM"
	echo "Errores de systemd en el arranque:"
	grep -E '\[FAILED\]' "$SERIE" | sed 's/^/  /' || echo "  ninguno"
} | tee "$SALIDA/resumen.txt"

[[ "$ESTADO" == "ok" ]] || error "La prueba de humo falló: ${ESTADO}. Revisa $SERIE"
echo "Prueba de humo superada. Captura: $SALIDA/escritorio.*"
