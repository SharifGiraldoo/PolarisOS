#!/usr/bin/env bash
# =============================================================================
# PolarisOS — crea la llave GPG que firma el repositorio APT.
#
# Se ejecuta UNA sola vez, en tu equipo:
#
#   ./scripts/crear-llave-repo.sh
#
# Resultado:
#   repo/polarisos-archive-keyring.asc   llave pública (se sube a Git)
#   ~/polarisos-repo-llave-privada.asc   llave privada (NUNCA se sube a Git)
#
# La llave privada no tiene contraseña porque la usa GitHub Actions sin nadie
# presente; por eso se guarda solo como secreto cifrado de GitHub y en un
# respaldo tuyo. Es una llave dedicada: solo sirve para firmar el repositorio.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
PUBLICA="$RAIZ/repo/polarisos-archive-keyring.asc"
PRIVADA="$HOME/polarisos-repo-llave-privada.asc"
NOMBRE="PolarisOS Archive Signing Key"
CORREO="164926102+SharifGiraldoo@users.noreply.github.com"

if [[ -f "$PUBLICA" ]]; then
	echo "Ya existe $PUBLICA. Si de verdad quieres cambiar la llave, bórrala primero." >&2
	exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GNUPGHOME="$TMP"
chmod 700 "$GNUPGHOME"

echo "Creando llave ed25519 para firmar el repositorio (válida por 3 años)..."
gpg --batch --quiet --passphrase '' --quick-gen-key "$NOMBRE <$CORREO>" ed25519 sign 3y
HUELLA="$(gpg --batch --list-keys --with-colons "$CORREO" | awk -F: '/^fpr:/ { print $10; exit }')"

gpg --batch --armor --export "$HUELLA" > "$PUBLICA"
umask 077
gpg --batch --armor --export-secret-keys "$HUELLA" > "$PRIVADA"

cat <<EOF

Llave creada. Huella: $HUELLA

  Pública: $PUBLICA
  Privada: $PRIVADA   (no la subas a Git)

Siguientes pasos:

  1. Guarda la llave privada como secreto de GitHub Actions:
       gh secret set APT_SIGNING_KEY < "$PRIVADA"

  2. Haz un respaldo de "$PRIVADA" fuera del computador
     (USB cifrada o gestor de contraseñas) y luego bórrala:
       shred -u "$PRIVADA"

  3. Sube la llave pública:
       git add repo/polarisos-archive-keyring.asc
       git commit -m "feat(repo): agrega la llave pública del repositorio APT"
       git push

GitHub Actions publicará el repositorio en GitHub Pages. Cuando el workflow
"Repositorio APT" termine en verde, las siguientes ISO ya incluirán el
repositorio propio.
EOF
