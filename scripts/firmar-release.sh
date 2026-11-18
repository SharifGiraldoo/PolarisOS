#!/usr/bin/env bash
# =============================================================================
# PolarisOS — firma con GPG las sumas de verificación de un release publicado
# por GitHub Actions y sube la firma al mismo release.
#
# La llave privada NUNCA se sube a GitHub: la firma se hace en tu equipo.
#
# Uso:   ./scripts/firmar-release.sh v0.1.0
# Requiere: gh (GitHub CLI) autenticado y una llave GPG (gpg --full-generate-key)
# =============================================================================
set -euo pipefail

ETIQUETA="${1:?Uso: $0 vX.Y.Z}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Descargando SHA256SUMS del release ${ETIQUETA}..."
gh release download "$ETIQUETA" --pattern SHA256SUMS --dir "$TMP"

echo "Contenido a firmar:"
cat "$TMP/SHA256SUMS"
read -r -p "¿Firmar este archivo? [s/N] " resp
[[ "$resp" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 1; }

gpg --armor --detach-sign --output "$TMP/SHA256SUMS.asc" "$TMP/SHA256SUMS"
gpg --verify "$TMP/SHA256SUMS.asc" "$TMP/SHA256SUMS"

gh release upload "$ETIQUETA" "$TMP/SHA256SUMS.asc" --clobber
echo "Firma publicada en el release ${ETIQUETA}."
echo "Recuerda publicar tu llave pública (por ejemplo en el README):"
echo "  gpg --armor --export TU_CORREO > polarisos-firma.asc"
