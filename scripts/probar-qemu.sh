#!/usr/bin/env bash
# =============================================================================
# PolarisOS — prueba la ISO en una máquina virtual QEMU con 2 GB de RAM.
#
# Uso:
#   ./scripts/probar-qemu.sh bios                 # arranque BIOS (equipos viejos)
#   ./scripts/probar-qemu.sh uefi                 # arranque UEFI
#   ./scripts/probar-qemu.sh secureboot           # UEFI con Secure Boot activado
#
#   Añade --disco para probar la instalación en un disco virtual de 20 GB, y
#   --solo-disco para arrancar el sistema ya instalado (sin la ISO):
#   ./scripts/probar-qemu.sh uefi --disco
#   ./scripts/probar-qemu.sh uefi --solo-disco
#
# Variables: ISO=ruta.iso  RAM=2048  CPUS=2
#            QEMU_EXTRA="-display none"   (opciones extra para QEMU)
# Requiere:  sudo apt install qemu-system-x86 qemu-utils ovmf
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
MODO="${1:-uefi}"
OPCION="${2:-}"
RAM="${RAM:-2048}"
CPUS="${CPUS:-2}"
# Por defecto, la ISO más reciente de salida/
ISO="${ISO:-$(find "$RAIZ/salida" -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null \
	| sort -rn | head -n 1 | cut -d' ' -f2-)}"
DISCO="$RAIZ/salida/disco-prueba-${MODO}.qcow2"
OVMF=/usr/share/OVMF

error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null || error "Instala QEMU: sudo apt install qemu-system-x86 qemu-utils ovmf"

ARGS=(-m "$RAM" -smp "$CPUS" -vga virtio -nic "user,model=virtio-net-pci"
      -usb -device usb-tablet -name "PolarisOS ($MODO)")

# Aceleración por hardware si está disponible (si no, será lento pero funciona)
if [[ -w /dev/kvm ]]; then
	ARGS+=(-enable-kvm -cpu host)
else
	echo "Aviso: /dev/kvm no disponible; la VM será lenta."
fi

case "$MODO" in
	bios)
		ARGS+=(-machine q35)
		;;
	uefi)
		VARS="$RAIZ/salida/OVMF_VARS-uefi.fd"
		[[ -f "$VARS" ]] || cp "$OVMF/OVMF_VARS_4M.fd" "$VARS"
		ARGS+=(-machine q35
		       -drive "if=pflash,format=raw,readonly=on,file=$OVMF/OVMF_CODE_4M.fd"
		       -drive "if=pflash,format=raw,file=$VARS")
		;;
	secureboot)
		# Variables con las llaves de Microsoft precargadas: Secure Boot ACTIVO
		VARS="$RAIZ/salida/OVMF_VARS-secureboot.fd"
		[[ -f "$VARS" ]] || cp "$OVMF/OVMF_VARS_4M.ms.fd" "$VARS"
		ARGS+=(-machine "q35,smm=on"
		       -global "driver=cfi.pflash01,property=secure,value=on"
		       -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF/OVMF_CODE_4M.secboot.fd"
		       -drive "if=pflash,format=raw,unit=1,file=$VARS")
		;;
	*)
		error "Modo desconocido: $MODO (usa bios, uefi o secureboot)"
		;;
esac

mkdir -p "$RAIZ/salida"
case "$OPCION" in
	--disco|--solo-disco)
		[[ -f "$DISCO" ]] || qemu-img create -f qcow2 "$DISCO" 20G
		ARGS+=(-drive "file=$DISCO,if=virtio,format=qcow2")
		;;
esac

if [[ "$OPCION" != "--solo-disco" ]]; then
	[[ -n "$ISO" && -f "$ISO" ]] || error "No encontré la ISO. Constrúyela primero o usa ISO=ruta.iso"
	ARGS+=(-cdrom "$ISO" -boot order=dc)
	echo "Arrancando $ISO en modo $MODO con ${RAM} MB de RAM..."
else
	echo "Arrancando el sistema instalado en modo $MODO..."
fi

# Opciones extra (por ejemplo, QEMU_EXTRA="-display none" en un servidor)
if [[ -n "${QEMU_EXTRA:-}" ]]; then
	read -r -a EXTRA <<< "$QEMU_EXTRA"
	ARGS+=("${EXTRA[@]}")
fi

exec qemu-system-x86_64 "${ARGS[@]}"
