# Registro de cambios

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto usa [versionado semántico](https://semver.org/lang/es/).

## [Sin publicar]

## [0.2.0] - Beta

### Cambiado
- **Inglés como idioma por defecto** (en_US.UTF-8, teclado `us`, hora UTC).
  Otros idiomas se eligen en el menú de arranque o en el instalador.
- `polaris-medir` ahora se llama `polaris-check` y reporta en inglés
  (el nombre anterior se mantiene como enlace).
- Meta de RAM en reposo ajustada a ≤ 1 GB en la sesión live.
- La imagen se publica como `polarisos-<versión>-amd64.iso` (sin ".hybrid"
  en el nombre; sigue arrancando desde DVD y USB).

### Añadido
- **Menú de arranque propio** (GRUB en BIOS y UEFI) con fondo y tema de
  PolarisOS: modo normal, gráficos seguros, cargar en RAM, persistencia,
  verificación del medio, submenú de idiomas, prueba de memoria (memtest86+),
  ajustes del firmware UEFI, reiniciar y apagar.
- **Pantalla de arranque gráfica** (Plymouth) con la marca de PolarisOS, en la
  sesión live y en el sistema instalado.
- Sumas de verificación `sha256sum.txt` dentro de la ISO y `.disk/info` propio.
- Bloqueo de pantalla (xfce4-screensaver), desactivado solo en la sesión live.
- Impresión (CUPS bajo demanda) y Bluetooth (solo si hay adaptador).
- Integración con máquinas virtuales (SPICE y VMware).
- Reproductor multimedia con códecs, calculadora, Discos y GParted.
- Hora sincronizada por red (systemd-timesyncd), páginas de manual y htop.
- Firefox con telemetría desactivada, protección contra rastreo y modo solo HTTPS.
- Presentación propia del instalador, `/etc/issue` y `/etc/motd` con la marca.
- **App de bienvenida** (`polaris-welcome`): actualizar, idiomas, driver
  NVIDIA con inscripción MOK para Secure Boot, Flathub, LibreOffice, Timeshift,
  firmware y documentación.
- **Aviso de actualizaciones** con un temporizador de usuario de systemd.
- **Repositorio APT propio** firmado en GitHub Pages
  (`polaris-archive-keyring`), para actualizar los paquetes de PolarisOS.
- **Snapshots** con Timeshift y **actualizaciones de firmware** con fwupd.
- **Lector de pantalla** Orca desde el menú de arranque.
- Menú **Whisker** en el panel de Xfce.
- **Privacidad de red:** MAC aleatoria al buscar redes, MAC estable por red
  y direcciones IPv6 temporales.
- **Ediciones Edu y Maker** (`make iso EDICION=...`).
- **Versión arm64** para equipos ARM con UEFI.
- CI: **prueba de humo** en QEMU, **SBOM** CycloneDX y **atestaciones de
  procedencia** en cada release; construcción de las 4 imágenes en paralelo.

### Corregido
- `/etc/os-release` mostraba "Debian": live-build lo copiaba como archivo;
  ahora es el enlace estándar al os-release de PolarisOS.
- Ícono del instalador con el logo de PolarisOS.
- Herramientas de construcción que faltaban en el contenedor (`apt-utils`, `wget`).


## [0.1.0] - Alfa

### Añadido
- Base Debian 13 "trixie" construida con live-build.
- Escritorio XFCE con LightDM, PipeWire y NetworkManager.
- Instalador gráfico Calamares con la marca de PolarisOS y cifrado de disco opcional.
- Synaptic para instalar paquetes de forma gráfica.
- Seguridad: UFW activo, actualizaciones automáticas, AppArmor, endurecimiento
  del kernel con sysctl, Secure Boot y contraseña mínima de 8 caracteres.
- Rendimiento: zram con zstd, earlyoom y límites al registro del sistema.
- Paquete `polaris-branding`: os-release, fondo, logo y tema por defecto.
- Construcción reproducible en contenedor y GitHub Actions con publicación de releases.
