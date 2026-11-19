#!/usr/bin/env python3
"""
PolarisOS — genera el SBOM (lista de materiales de software) de una ISO.

Lee el manifiesto de paquetes que crea live-build (<imagen>.packages, con
líneas "paquete[:arquitectura]<TAB>versión") y escribe un SBOM en formato
CycloneDX 1.5 (JSON) con un identificador purl por cada paquete de Debian.

Uso:
    scripts/generar-sbom.py salida/polarisos-0.2.0-amd64.packages
    -> salida/polarisos-0.2.0-amd64.cdx.json
"""
import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone
from urllib.parse import quote

DISTRO = "debian-13"


def leer_manifiesto(ruta, arquitectura):
    paquetes = []
    with open(ruta, encoding="utf-8") as f:
        for linea in f:
            partes = linea.split()
            if len(partes) < 2:
                continue
            nombre, version = partes[0], partes[1]
            arch = arquitectura
            if ":" in nombre:
                nombre, arch = nombre.split(":", 1)
            paquetes.append((nombre, version, arch))
    return sorted(set(paquetes))


def purl(nombre, version, arch):
    origen = "polarisos" if nombre.startswith("polaris-") else "debian"
    return (f"pkg:deb/{origen}/{nombre.lower()}@{quote(version, safe='')}"
            f"?arch={arch}&distro={DISTRO}")


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    ruta = sys.argv[1]
    base = os.path.basename(ruta)
    m = re.match(r"(?P<imagen>.+)-(?P<version>\d+\.\d+\.\d+[^-]*)-(?P<arch>amd64|arm64)\.packages$", base)
    if not m:
        print(f"Nombre inesperado: {base} (se espera <nombre>-<versión>-<arch>.packages)", file=sys.stderr)
        return 1
    imagen, version, arch = m.group("imagen"), m.group("version"), m.group("arch")

    componentes = []
    for nombre, ver, arq in leer_manifiesto(ruta, arch):
        identificador = purl(nombre, ver, arq)
        componentes.append({
            "type": "library",
            "bom-ref": identificador,
            "name": nombre,
            "version": ver,
            "purl": identificador,
        })

    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "tools": {"components": [{"type": "application", "name": "polarisos-generar-sbom"}]},
            "component": {
                "type": "operating-system",
                "bom-ref": f"{imagen}-{version}-{arch}",
                "name": imagen.replace("polarisos", "PolarisOS", 1),
                "version": version,
                "description": f"PolarisOS ISO image for {arch}, based on Debian 13 (trixie)",
                "licenses": [{"license": {"id": "GPL-3.0-or-later"}}],
                "externalReferences": [
                    {"type": "vcs", "url": "https://github.com/SharifGiraldoo/PolarisOS"}
                ],
            },
        },
        "components": componentes,
    }

    destino = re.sub(r"\.packages$", ".cdx.json", ruta)
    with open(destino, "w", encoding="utf-8") as f:
        json.dump(sbom, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"SBOM con {len(componentes)} paquetes: {destino}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
