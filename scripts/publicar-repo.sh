#!/usr/bin/env bash
# =============================================================================
# PolarisOS — arma el repositorio APT firmado a partir de los .deb.
#
# Uso:   APT_SIGNING_KEY="$(cat llave-privada.asc)" \
#          scripts/publicar-repo.sh DIRECTORIO_DEBS DIRECTORIO_SITIO
#
# Deja en DIRECTORIO_SITIO un sitio estático listo para GitHub Pages:
#   index.html                          página con las instrucciones
#   apt/dists/trixie/...                índices firmados (InRelease, Release.gpg)
#   apt/pool/main/...                   paquetes .deb
#   apt/polarisos-archive-keyring.asc   llave pública
#
# Requiere: reprepro y gnupg. Lo ejecuta el workflow repositorio-apt.yml.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DEBS="$(realpath "${1:?Uso: $0 DIRECTORIO_DEBS DIRECTORIO_SITIO}")"
SITIO="$(realpath -m "${2:?Uso: $0 DIRECTORIO_DEBS DIRECTORIO_SITIO}")"
PUBLICA="$RAIZ/repo/polarisos-archive-keyring.asc"

[[ -n "${APT_SIGNING_KEY:-}" ]] || { echo "ERROR: falta la variable APT_SIGNING_KEY" >&2; exit 1; }
[[ -f "$PUBLICA" ]] || { echo "ERROR: falta $PUBLICA (ver scripts/crear-llave-repo.sh)" >&2; exit 1; }
ls "$DEBS"/*.deb >/dev/null 2>&1 || { echo "ERROR: no hay .deb en $DEBS" >&2; exit 1; }

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT
chmod 700 "$GNUPGHOME"
printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --quiet --import
HUELLA="$(gpg --batch --list-secret-keys --with-colons | awk -F: '/^fpr:/ { print $10; exit }')"
[[ -n "$HUELLA" ]] || { echo "ERROR: APT_SIGNING_KEY no contiene una llave privada" >&2; exit 1; }

# La llave del secreto debe ser la misma que la pública publicada en Git
HUELLA_PUBLICA="$(gpg --batch --with-colons --import-options show-only --import "$PUBLICA" \
	| awk -F: '/^fpr:/ { print $10; exit }')"
if [[ "$HUELLA" != "$HUELLA_PUBLICA" ]]; then
	echo "ERROR: la llave privada ($HUELLA) no corresponde a repo/polarisos-archive-keyring.asc ($HUELLA_PUBLICA)" >&2
	exit 1
fi

rm -rf "$SITIO"
mkdir -p "$SITIO/apt/conf"
cat > "$SITIO/apt/conf/distributions" <<EOF
Origin: PolarisOS
Label: PolarisOS
Codename: trixie
Suite: stable
Architectures: amd64 arm64
Components: main
Description: PolarisOS packages for Debian 13 (trixie)
SignWith: $HUELLA
EOF

for deb in "$DEBS"/*.deb; do
	reprepro --basedir "$SITIO/apt" includedeb trixie "$deb"
done

# reprepro solo necesita conf/ y db/ para trabajar; no se publican
rm -rf "$SITIO/apt/conf" "$SITIO/apt/db"
cp "$PUBLICA" "$SITIO/apt/polarisos-archive-keyring.asc"

PAQUETES="$(find "$DEBS" -maxdepth 1 -name "*.deb" -printf "%f\n" | sort | sed 's|^|<li><code>|; s|$|</code></li>|')"
cat > "$SITIO/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PolarisOS APT repository</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 760px; margin: 3rem auto; padding: 0 1rem;
         background: #060c26; color: #e8edf7; line-height: 1.55; }
  a { color: #7cc4ff; } code, pre { background: #0e2e54; border-radius: 6px; }
  code { padding: 0.1rem 0.35rem; } pre { padding: 1rem; overflow-x: auto; }
</style>
</head>
<body>
<h1>PolarisOS APT repository</h1>
<p>Signed Debian repository with the PolarisOS packages for Debian 13 (trixie).
PolarisOS installs it automatically. To add it to another Debian 13 system:</p>
<pre>sudo wget -O- https://sharifgiraldoo.github.io/PolarisOS/apt/polarisos-archive-keyring.asc \\
  | sudo gpg --dearmor -o /usr/share/keyrings/polarisos-archive-keyring.gpg
sudo apt install ./polaris-archive-keyring_*.deb   # or add polarisos.sources by hand
sudo apt update</pre>
<p>Key fingerprint: <code>$HUELLA</code></p>
<h2>Packages</h2>
<ul>
$PAQUETES
</ul>
<p><a href="https://github.com/SharifGiraldoo/PolarisOS">Source code on GitHub</a> · Free as in Freedom</p>
</body>
</html>
EOF

echo "Repositorio publicado en $SITIO (llave $HUELLA)"
find "$SITIO" -type f | sort
