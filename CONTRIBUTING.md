# Cómo contribuir a PolarisOS

¡Gracias por tu interés! Así puedes ayudar:

## Reportar errores
Abre un *issue* con:
- Modelo del equipo, RAM y si arranca en BIOS o UEFI
- Salida de `polaris-check` (dentro de PolarisOS)
- Pasos para reproducir el problema

## Proponer cambios
1. Haz un *fork* y crea una rama: `git checkout -b mejora/descripcion-corta`
2. Haz tus cambios. Si tocas scripts, revisa con `make revisar`.
3. Construye y prueba: `make iso` y `make probar-uefi`
4. Si tu cambio agrega paquetes, mide la RAM en reposo con `polaris-check`
   e indica el antes y el después en el *pull request*.
5. Abre el *pull request* explicando qué cambia y por qué.

## Reglas del proyecto
- **Ligereza:** la RAM en reposo no debe superar 1024 MB en la sesión live. Todo paquete nuevo
  debe justificarse.
- **Seguridad:** no se agregan servicios que escuchen en red por defecto.
- **Mensajes de commit** con [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/):
  `tipo(ámbito opcional): descripción`, con la descripción en español, en
  minúscula y en modo imperativo.

## Conventional Commits

| Tipo | Cuándo usarlo | Ejemplo |
|---|---|---|
| `feat` | Una función nueva para el usuario | `feat(apps): agrega un lector de PDF` |
| `fix` | Corrige un error | `fix(arranque): corrige el fondo en monitores 4K` |
| `perf` | Mejora el rendimiento o el consumo de RAM | `perf(memoria): reduce el tamaño de zram` |
| `docs` | Solo documentación | `docs(guia): explica cómo probar en VirtualBox` |
| `build` | live-build, empaquetado o scripts de construcción | `build(live-build): activa la compresión xz` |
| `ci` | GitHub Actions | `ci: guarda la ISO por 14 días` |
| `test` | Pruebas (QEMU, verificaciones) | `test: agrega la prueba de Secure Boot` |
| `refactor` | Cambia código sin cambiar su comportamiento | `refactor(hooks): separa la configuración de UFW` |
| `chore` | Mantenimiento que no encaja en los anteriores | `chore: actualiza el .gitignore` |

Ámbitos usados en el proyecto: `paquetes`, `escritorio`, `apps`, `seguridad`,
`hardware`, `instalador`, `arranque`, `branding`, `identidad`, `memoria`,
`iso`, `herramientas`, `live-build`, `readme`, `release`, `bienvenida`,
`repo`, `ediciones`, `edu`, `maker`, `arm64`, `accesibilidad`, `red`, `ci`.

Un cambio que rompe la compatibilidad lleva `!` después del tipo o una línea
`BREAKING CHANGE:` al final del mensaje: `feat(arranque)!: cambia a systemd-boot`.
