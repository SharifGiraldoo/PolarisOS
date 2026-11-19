# Política de seguridad de PolarisOS

## Versiones con soporte

| Versión | Base | Soporte de seguridad |
|---|---|---|
| 0.x | Debian 13 "trixie" | Sí, mientras Debian 13 reciba actualizaciones de seguridad |

Las actualizaciones de seguridad de los paquetes del sistema provienen
directamente del equipo de seguridad de Debian y se instalan automáticamente
(`unattended-upgrades`).

## Reportar una vulnerabilidad

**No abras un issue público.** Usa la opción
[*Report a vulnerability*](../../security/advisories/new) de la pestaña
*Security* de este repositorio (aviso privado de GitHub).

Incluye:
- Versión de PolarisOS (`cat /etc/os-release`)
- Pasos para reproducir el problema
- Impacto que estimas

Respuesta inicial esperada: 7 días.

Si la vulnerabilidad está en un paquete de Debian (y no en la configuración o
los paquetes propios de PolarisOS), repórtala también a
<https://www.debian.org/security/>.

## Verificar las descargas

Cada versión publica `SHA256SUMS` y su firma `SHA256SUMS.asc`:

```bash
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
```

Además, cada ISO tiene una **atestación de procedencia** de GitHub (prueba
de que se construyó en GitHub Actions desde este repositorio) y un **SBOM**
(`.cdx.json`) con todos sus paquetes:

```bash
gh attestation verify polarisos-<versión>-amd64.iso --repo SharifGiraldoo/PolarisOS
```

## Repositorio APT

Los paquetes propios se publican firmados con una llave dedicada (ver
`repo/README.md`). La llave privada solo existe como secreto cifrado de
GitHub Actions y en un respaldo fuera de línea del mantenedor.
