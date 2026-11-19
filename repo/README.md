# Repositorio APT de PolarisOS

Los paquetes propios (`polaris-branding`, `polaris-welcome`,
`polaris-archive-keyring`) se publican como repositorio APT firmado en
GitHub Pages:

```
https://sharifgiraldoo.github.io/PolarisOS/apt   (trixie main)
```

Así, los sistemas instalados reciben las mejoras de PolarisOS con
`sudo apt update && sudo apt upgrade`, igual que las de Debian.

## Archivos

| Archivo | Qué es |
|---|---|
| `polarisos-archive-keyring.asc` | Llave **pública** que firma el repositorio. Se crea con `scripts/crear-llave-repo.sh` y sí se sube a Git. |

La llave **privada** nunca se sube al repositorio: vive solo en el secreto
`APT_SIGNING_KEY` de GitHub Actions y en un respaldo tuyo fuera de Git.

Mientras `polarisos-archive-keyring.asc` no exista, la ISO se construye sin
el repositorio propio (todo lo demás funciona igual). La configuración paso a
paso está en `docs/GUIA.md`, sección "Repositorio APT propio".
