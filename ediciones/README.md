# Ediciones de PolarisOS

Cada carpeta es una **edición**: se copia encima de `config/` antes de
construir, así que puede agregar listas de paquetes, hooks y archivos sin
cambiar la edición estándar.

| Edición | Para quién | Construir |
|---|---|---|
| `estandar` | Uso general (no tiene carpeta: es `config/` tal cual) | `make iso` |
| `edu` | Colegios y niños: juegos educativos, dibujo, mecanografía, Scratch y GeoGebra, DNS familiar | `make iso EDICION=edu` |
| `maker` | Electrónica y robótica: Arduino IDE, Thonny, esptool, KiCad, puerto serie listo | `make iso EDICION=maker` |

Estructura de una edición (todo es opcional):

```
ediciones/<nombre>/
├── package-lists/   listas extra (*.list.chroot)
├── hooks/normal/    hooks extra (*.hook.chroot)
└── includes.chroot/ archivos que se copian al sistema
```

Para crear una edición nueva: copia una carpeta, cámbiale el nombre y agrégala
en `auto/config` (bloque `case "${POLARIS_EDICION}"`) y en la matriz de
`.github/workflows/construir-iso.yml`.
