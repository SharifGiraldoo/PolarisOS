# Guía completa: construir PolarisOS y publicarla en GitHub

Esta guía va desde un equipo con Q4OS (o cualquier Linux basado en Debian)
hasta una versión publicada en GitHub con su ISO firmada. Sigue las partes en
orden; cada una termina con una verificación para que sepas si quedó bien.

**Tiempo estimado:** una tarde para la primera ISO, y un día más para pulir y
publicar.

---

## Índice

0. [Cómo funciona (en 2 minutos)](#parte-0--cómo-funciona-en-2-minutos)
1. [Preparar tu equipo Q4OS](#parte-1--preparar-tu-equipo-q4os)
2. [Crear el repositorio local](#parte-2--crear-el-repositorio-local)
3. [Entender la estructura](#parte-3--entender-la-estructura)
4. [Personalizar PolarisOS](#parte-4--personalizar-polarisos)
5. [Construir la ISO](#parte-5--construir-la-iso)
6. [Probar en máquina virtual](#parte-6--probar-en-máquina-virtual)
7. [Probar la instalación](#parte-7--probar-la-instalación)
8. [Probar en hardware real](#parte-8--probar-en-hardware-real)
9. [Subir el proyecto a GitHub](#parte-9--subir-el-proyecto-a-github)
10. [Publicar la primera versión](#parte-10--publicar-la-primera-versión-v010)
11. [Mantenimiento](#parte-11--mantenimiento)
12. [Siguientes pasos](#parte-12--siguientes-pasos)
13. [Solución de problemas](#parte-13--solución-de-problemas)

---

## Parte 0 — Cómo funciona (en 2 minutos)

PolarisOS **no** se construye desde cero: es una *derivada* de Debian 13
"trixie". Eso nos da el gestor de paquetes `apt`, decenas de miles de paquetes
y los parches del equipo de seguridad de Debian. Nuestro trabajo es elegir,
integrar, configurar y darle identidad.

```
 auto/config + config/  ──►  live-build  ──►  ISO híbrida (USB/DVD, BIOS/UEFI)
         ▲                     │
         │            descarga paquetes de Debian,
   tu código en Git   instala en un "chroot", ejecuta
                      tus hooks y empaqueta todo
```

- **live-build** es la herramienta oficial de Debian para crear imágenes live.
- Un **chroot** es un sistema Linux completo dentro de una carpeta: ahí se
  instala PolarisOS antes de comprimirlo en la ISO.
- Los **hooks** son scripts que corren dentro de ese chroot para configurarlo.
- **Calamares** es el instalador gráfico que copia el sistema live al disco.

---

## Parte 1 — Preparar tu equipo Q4OS

### 1.1 Verifica tu sistema

```bash
cat /etc/debian_version      # 13.x = Q4OS 6 Andromeda · 12.x = Q4OS 5 Aquarius
uname -m                     # debe decir x86_64
free -h                      # ideal: 4 GB o más
df -h ~                      # se necesitan al menos 15 GB libres (ideal 30 GB)
grep -c -E 'vmx|svm' /proc/cpuinfo   # mayor que 0 = soporta virtualización
```

> **¿Q4OS 5 o 6?** No importa: la construcción ocurre dentro de un contenedor
> Debian 13, así que funciona igual en ambas.
>
> **¿Tu equipo es de 32 bits (`i686`)?** No podrás construir ni probar la ISO
> de 64 bits en él. Necesitarás otro equipo o usar solo GitHub Actions
> (Parte 9).

**Antes de seguir:** toma una línea base de tu Q4OS. Reinicia, inicia sesión
sin abrir nada y ejecuta `free -m`. Anota el valor de la columna `used`: es
la referencia contra la que compararás PolarisOS.

### 1.2 Instala las herramientas

```bash
sudo apt update
sudo apt install git make podman qemu-system-x86 qemu-utils ovmf \
                 shellcheck gnupg gh python3-pil
```

| Herramienta | Para qué |
|---|---|
| `git`, `gh` | Control de versiones y GitHub desde la terminal |
| `make` | Atajos (`make iso`, `make probar-uefi`...) |
| `podman` | Contenedor Debian 13 limpio para construir |
| `qemu-system-x86`, `qemu-utils`, `ovmf` | Máquinas virtuales BIOS/UEFI/Secure Boot |
| `shellcheck` | Revisa errores en los scripts |
| `gnupg` | Firma de las versiones publicadas |
| `python3-pil` | Regenerar el arte (logo y fondos) |

### 1.3 Permite usar aceleración por hardware (KVM)

```bash
sudo usermod -aG kvm "$USER"
```

Cierra sesión y vuelve a entrar. Verifica con `ls -l /dev/kvm` y `groups`
(debe aparecer `kvm`). Si tu BIOS tiene la virtualización desactivada
(VT-x / AMD-V / SVM), actívala ahí.

### 1.4 Configura Git

```bash
git config --global user.name  "Sharif Giraldo"
git config --global user.email "tu-correo@ejemplo.com"
git config --global init.defaultBranch main
```

✅ **Verificación:** `podman --version`, `qemu-system-x86_64 --version` y
`git --version` responden sin error.

---

## Parte 2 — Crear el repositorio local

Descomprime el proyecto en tu carpeta personal e inicia Git:

```bash
cd ~
unzip PolarisOS.zip           # crea la carpeta ~/PolarisOS
cd PolarisOS
chmod +x auto/* scripts/*.sh config/hooks/normal/*.hook.chroot   # por si se perdieron los permisos
git init
git add .
git commit -m "Estructura inicial de PolarisOS 0.1.0"
```

Desde aquí, **haz un commit cada vez que algo funcione**. Si un cambio rompe la
ISO, `git diff` y `git log` te dirán qué cambió.

✅ **Verificación:** `git log --oneline` muestra tu primer commit y
`make` muestra la lista de tareas.

---

## Parte 3 — Entender la estructura

| Ruta | Qué hace | ¿Lo editas a menudo? |
|---|---|---|
| `auto/config` | Opciones de live-build: base Debian 13, Secure Boot, idioma, nombre de la ISO | A veces |
| `config/package-lists/*.list.chroot` | Paquetes instalados en el sistema, agrupados por tema | **Sí** |
| `config/package-lists/*.list.binary` | Paquetes guardados en la ISO para que Calamares instale GRUB sin internet | Rara vez |
| `config/hooks/normal/0100-seguridad…` | Firewall, actualizaciones automáticas, sysctl, AppArmor | A veces |
| `config/hooks/normal/0200-rendimiento…` | zram, earlyoom, límites de registros | A veces |
| `config/hooks/normal/0050-identidad…` | `/etc/os-release`, `/etc/issue` y `/etc/motd` de PolarisOS | Rara vez |
| `config/hooks/normal/0250-escritorio…` | Pantalla de arranque (Plymouth) y applet de Bluetooth bajo demanda | Rara vez |
| `config/hooks/normal/0300-instalador…` | Marca del instalador Calamares | Rara vez |
| `config/hooks/normal/9000-disk-info.hook.binary` | Nombre del medio de instalación (`.disk/info`) | Rara vez |
| `config/bootloaders/grub-pc/` | Menú de arranque: opciones, idiomas, tema y fondo (`splash.png`) | A veces |
| `config/includes.chroot/` | Archivos copiados tal cual al sistema: diapositivas del instalador, políticas de Firefox, `splash` en GRUB | A veces |
| `packages/polaris-branding/` | Paquete `.deb` propio: os-release, fondo, logo, tema y el verificador `polaris-check` | Al cambiar la identidad |
| `scripts/` | Construir, probar en QEMU y firmar releases | Rara vez |
| `.github/workflows/` | Integración continua y releases | Rara vez |

### Decisiones de diseño importantes

1. **`--apt-recommends false`.** Es la decisión que más RAM y disco ahorra.
   La contraparte: si falta algo (por ejemplo, el applet de sonido), hay que
   agregarlo explícitamente a una lista de paquetes.
2. **Kernel y GRUB firmados de Debian.** Permiten Secure Boot. Por eso no
   compilamos un kernel propio: perderíamos la firma.
3. **`os-release` en un paquete con `dpkg-divert`.** Si lo copiáramos con
   `includes.chroot`, la siguiente actualización de `base-files` lo borraría.
4. **`VERSION_CODENAME=trixie` en os-release.** `unattended-upgrades` usa
   ese valor para encontrar las actualizaciones de seguridad de Debian.
   **No lo cambies**, o las actualizaciones automáticas dejarán de funcionar
   en silencio.

---

## Parte 4 — Personalizar PolarisOS

Todo es opcional para la primera ISO. Lo más común:

### 4.1 Idioma, teclado y zona horaria de la sesión live

PolarisOS arranca en **inglés** (Estados Unidos), con teclado `us` y hora UTC.
Se define en `auto/config`, variable `LIVE_COMUN`:

```
locales=en_US.UTF-8 keyboard-layouts=us timezone=Etc/UTC
```

El usuario puede elegir otro idioma de dos formas, sin cambiar la ISO:
- En el menú de arranque: **Languages ...** (español, portugués, francés, alemán).
- En el instalador Calamares, que configura idioma, teclado y zona horaria
  del sistema instalado.

Para agregar idiomas al menú, edita el submenú `Languages` en
`config/bootloaders/grub-pc/grub.cfg`.

### 4.2 Agregar o quitar paquetes

Edita el archivo `.list.chroot` que corresponda (un paquete por línea). Para
buscar nombres exactos dentro del contenedor:

```bash
sudo podman run --rm -it debian:trixie bash -c \
  "apt-get update -qq && apt-cache search video editor"
```

Cada paquete agregado sube la RAM o el tamaño de la ISO. **Mide** con
`polaris-check` (dentro de PolarisOS) después de cada cambio importante (Parte 6).

### 4.3 Cambiar el arte

Reemplaza los PNG manteniendo nombres y tamaños:

| Archivo | Uso | Tamaño |
|---|---|---|
| `packages/polaris-branding/files/polarisos-fondo.png` | Fondo de escritorio y de inicio de sesión | 1920×1080 |
| `packages/polaris-branding/files/polarisos-logo.png` | Logo del sistema | 256×256 |
| `config/includes.chroot/etc/calamares/branding/polaris/logo.png` | Logo del instalador | 256×256 |
| `config/includes.chroot/etc/calamares/branding/polaris/welcome.png` | Bienvenida del instalador | 800×450 |

O modifica los colores en `assets/generar-arte.py` y ejecuta `make arte`.

### 4.4 Si usas otro usuario de GitHub

Reemplaza `SharifGiraldoo` en todo el repositorio:

```bash
grep -rl SharifGiraldoo . --exclude-dir=.git | xargs sed -i 's/SharifGiraldoo/TU_USUARIO/g'
```

✅ **Verificación:** `make revisar` termina sin errores. Haz commit.

---

## Parte 5 — Construir la ISO

```bash
cd ~/PolarisOS
make iso
```

Te pedirá la contraseña de `sudo` (el contenedor necesita privilegios para
crear el sistema de archivos). Por dentro, `scripts/construir.sh`:

1. Inicia un contenedor `debian:trixie` limpio.
2. Copia el proyecto dentro (tu carpeta no se llena de archivos de root).
3. Construye el paquete `polaris-branding`.
4. Ejecuta `lb config` y `lb build`.
5. Deja el resultado en `salida/`.

**Duración:** 20 a 60 minutos la primera vez (descarga unos cientos de MB).
Las siguientes son más rápidas, porque los paquetes quedan en caché en el
volumen `polarisos-cache`.

La versión se toma del archivo `VERSION`. Para una prueba puntual usa
`make iso VERSION=0.2.0-prueba`, y para borrar también la caché,
`LIMPIEZA_TOTAL=1 make iso`.

✅ **Verificación:**

```bash
ls -lh salida/
# polarisos-0.2.0-amd64.iso   (aprox. 1,2 – 1,8 GB)
# SHA256SUMS
# build-0.1.0.log
grep "\[PolarisOS\]" salida/build-0.1.0.log   # tus hooks se ejecutaron
```

Si falla, ve a la [Parte 13](#parte-13--solución-de-problemas).

---

## Parte 6 — Probar en máquina virtual

Todas las pruebas usan **2 GB de RAM**, el límite del requisito.

```bash
make probar-bios          # equipos viejos (BIOS / legacy)
make probar-uefi          # equipos modernos (UEFI)
make probar-secureboot    # UEFI con Secure Boot ACTIVO
```

Dentro de PolarisOS (sesión live), espera a que cargue el escritorio, abre
una terminal **sin abrir otras aplicaciones** y ejecuta el medidor que viene
incluido en el sistema:

```bash
polaris-check
```

Revisa:

- [ ] La RAM en reposo es de 1024 MB o menos (en modo live; instalado consume menos)
- [ ] El firewall (UFW) está activo
- [ ] AppArmor está habilitado
- [ ] zram y earlyoom están activos
- [ ] Con `make probar-secureboot`, el reporte dice "Secure Boot ACTIVO"
- [ ] Sonido (`pavucontrol`), red y Firefox funcionan
- [ ] Synaptic abre e instala un paquete (por ejemplo `cowsay`)
- [ ] Al arrancar se ve el **menú de PolarisOS** y luego la **pantalla de carga** con el logo
- [ ] En el menú: **Languages → Español (Latinoamérica)** arranca el escritorio en español
- [ ] En el menú: **Check disc for defects** termina sin errores
- [ ] En el menú: **Advanced options → Memory Diagnostic Tool** abre memtest86+

> La sesión live usa el usuario `polaris` sin contraseña. Para `sudo` no te
> pedirá clave en modo live.

Si la RAM supera la meta, el reporte muestra los procesos que más memoria
consumen. Quita lo que no sea esencial o cambia XFCE por LXQt.

---

## Parte 7 — Probar la instalación

```bash
make instalar-prueba      # VM UEFI con la ISO y un disco virtual de 20 GB
```

1. Haz doble clic en **"Install PolarisOS"**, en el escritorio.
2. Recorre Calamares: idioma, zona horaria, teclado, particiones ("Borrar
   disco") y usuario. Prueba también la casilla **"Cifrar sistema"**.
3. Al terminar, cierra la VM y arranca el disco instalado:

```bash
make arrancar-instalado
```

✅ **Verificación en el sistema instalado:**

```bash
cat /etc/os-release                 # NAME="PolarisOS"
dpkg-divert --list | grep os-release # desvío activo
sudo ufw status                     # Status: active
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -i "allowed origins"
dpkg -l | grep -E 'live-boot|calamares'   # no debe aparecer nada
polaris-check
```

Repite la instalación en modo BIOS y con Secure Boot. Cada modo usa su propio
disco virtual:

```bash
./scripts/probar-qemu.sh bios --disco            # instalar
./scripts/probar-qemu.sh bios --solo-disco       # arrancar lo instalado
./scripts/probar-qemu.sh secureboot --disco
./scripts/probar-qemu.sh secureboot --solo-disco
```

> ⚠️ **Prueba crítica:** el sistema instalado debe arrancar con Secure Boot.
> Si se detiene en la consola de GRUB, consulta "Secure Boot falla después de
> instalar" en la Parte 13.

---

## Parte 8 — Probar en hardware real

Aquí se valida el requisito de "funcionar en cualquier dispositivo".

### 8.1 Grabar la ISO en una USB

```bash
lsblk                       # identifica tu USB, por ejemplo /dev/sdb (¡no tu disco!)
sudo dd if=salida/polarisos-0.2.0-amd64.iso of=/dev/sdX \
        bs=4M status=progress oflag=sync
```

> ⚠️ `dd` borra todo el destino sin preguntar. Revisa `/dev/sdX` dos veces.
> Como alternativa gráfica puedes usar GNOME Disks ("Restaurar imagen de
> disco") o Ventoy.

### 8.2 Arranca en modo live (sin instalar)

En tu equipo con Q4OS, entra al menú de arranque (normalmente F12, F11, F8 o
Esc) y elige la USB. **El modo live no toca tu disco**, así que puedes probar
sin riesgo.

### 8.3 Matriz de pruebas

Prueba en al menos 3 equipos distintos y anota los resultados en un issue de
GitHub:

| Equipo | CPU | RAM | BIOS/UEFI | Wi-Fi | Sonido | Video | Suspensión | RAM en reposo |
|---|---|---|---|---|---|---|---|---|
| Equipo Q4OS | | | | | | | | |
| Portátil viejo | | | | | | | | |
| Equipo de la universidad | | | | | | | | |

Si algo no funciona: `lspci -nnk` y `sudo dmesg | grep -i firmware` muestran
qué controlador o firmware falta. Agrégalo a `05-firmware.list.chroot`.

---

## Parte 9 — Subir el proyecto a GitHub

### 9.1 Inicia sesión desde la terminal

```bash
gh auth login
# GitHub.com → HTTPS → Login with a web browser
```

### 9.2 Crea el repositorio y sube el código

Desde `~/PolarisOS`, con todo en commits:

```bash
git status                           # debe decir "nothing to commit"
gh repo create PolarisOS --public \
   --description "Distribución Linux ligera y segura basada en Debian 13" \
   --source=. --remote=origin --push
```

> **Nunca subas la ISO a Git.** El `.gitignore` ya excluye `salida/`, `*.iso`
> y los directorios de trabajo. GitHub rechaza archivos de más de 100 MB; las
> ISO van en **Releases** (Parte 10).

### 9.3 Configura el repositorio

```bash
# Temas para que otros lo encuentren
gh repo edit --add-topic linux,linux-distribution,debian,live-build,xfce,lightweight

# Reporte privado de vulnerabilidades (lo menciona SECURITY.md)
gh api -X PUT repos/SharifGiraldoo/PolarisOS/private-vulnerability-reporting
```

En la web (**Settings**):

- **Branches → Add branch ruleset** para `main`: exige que el check "Revisar
  scripts" pase antes de fusionar.
- **Actions → General**: deja "Allow all actions".

✅ **Verificación:** en la pestaña **Actions** aparece el workflow
"Construir ISO" y el trabajo **Revisar scripts** termina en verde.

### 9.4 Prueba la construcción en la nube (opcional)

**Actions → Construir ISO → Run workflow.** En unos 40 minutos tendrás la ISO
como *artefacto* descargable (se guarda 7 días). Así compruebas que el proyecto
compila en una máquina limpia, no solo en la tuya.

---

## Parte 10 — Publicar la primera versión (v0.1.0)

### 10.1 Crea tu llave de firma (una sola vez)

```bash
gpg --full-generate-key
# Tipo: ECC (firma) · Curva: 25519 · Caducidad: 2y
# Nombre: Sharif Giraldo · Correo: el mismo de Git

gpg --armor --export tu-correo@ejemplo.com > polarisos-firma.asc
git add polarisos-firma.asc
git commit -m "Agrega la llave pública de firma de releases"
git push
```

> 🔐 La llave **privada** nunca sale de tu equipo. Haz un respaldo cifrado:
> `gpg --export-secret-keys --armor tu-correo > respaldo-privado.asc`, y
> guárdalo fuera del repositorio (USB, gestor de contraseñas).

### 10.2 Lista de verificación antes de publicar

- [ ] Partes 6, 7 y 8 superadas
- [ ] `CHANGELOG.md` actualizado
- [ ] La versión coincide en todos los lugares (ver 11.2)

### 10.3 Crea la etiqueta

```bash
git tag -a v0.1.0 -m "PolarisOS 0.1.0 (Alfa)"
git push origin v0.1.0
```

La etiqueta dispara GitHub Actions, que construye la ISO y crea el **Release**
con la ISO y `SHA256SUMS`. Al ser una versión `0.x`, queda marcada como
*pre-release*.

### 10.4 Firma el release

Cuando termine el workflow:

```bash
./scripts/firmar-release.sh v0.1.0
```

El script descarga `SHA256SUMS`, te lo muestra, lo firma con tu llave y sube
`SHA256SUMS.asc` al release.

✅ **Verificación (como lo haría un usuario):**

```bash
mkdir /tmp/verificar && cd /tmp/verificar
gh release download v0.1.0 --repo SharifGiraldoo/PolarisOS
curl -sLO https://raw.githubusercontent.com/SharifGiraldoo/PolarisOS/main/polarisos-firma.asc
gpg --import polarisos-firma.asc
gpg --verify SHA256SUMS.asc SHA256SUMS      # "Good signature"
sha256sum -c SHA256SUMS                     # OK
```

### Alternativa: publicar una ISO construida en tu equipo

```bash
gpg --armor --detach-sign salida/SHA256SUMS
gh release create v0.1.0 salida/*.iso salida/SHA256SUMS salida/SHA256SUMS.asc \
   --title "PolarisOS 0.1.0" --notes-file CHANGELOG.md --prerelease
```

(Si usas esta vía, quita el disparador `tags` del workflow para que no haya
dos releases con la misma etiqueta.)

---

## Parte 11 — Mantenimiento

### 11.1 Flujo de trabajo con ramas

```bash
git switch -c mejora/agregar-lxqt     # rama por cambio
# ...cambios, make iso, make probar-uefi...
git push -u origin mejora/agregar-lxqt
gh pr create --fill                    # el CI revisa los scripts
```

### 11.2 Al publicar una nueva versión, actualiza la versión en

| Archivo | Campo |
|---|---|
| `VERSION` | la versión completa, por ejemplo `0.2.0` (la leen `make`, los scripts y `auto/config`) |
| `packages/polaris-branding/files/os-release` | `VERSION_ID="0.2"`, `VERSION`, `PRETTY_NAME` |
| `packages/polaris-branding/debian/changelog` | nueva entrada arriba (`dch -v 0.2.0` o a mano) |
| `config/includes.chroot/etc/calamares/branding/polaris/branding.desc` | `version`, `shortVersion`, `versionedName`, `shortVersionedName` |
| `CHANGELOG.md` | nueva sección |

Si alguna no coincide con la etiqueta, GitHub Actions **detiene la publicación**
y te dice cuál falta. Así no publicas una ISO que diga "0.1" siendo la 0.2.

### 11.3 Ciclo de versiones sugerido

- **Parche (0.1.x):** reconstruye cuando Debian publique una versión de punto
  (13.x) o una corrección de seguridad importante. Los usuarios instalados ya
  reciben esas actualizaciones por `apt`; la ISO nueva solo sirve para
  instalaciones nuevas.
- **Menor (0.x.0):** funciones nuevas (más idiomas, otra variante de escritorio).
- **Mayor (1.0.0):** cuando las pruebas de hardware real sean estables y la
  documentación esté completa.

### 11.4 Seguridad continua

- Suscríbete a las alertas de seguridad de Debian: <https://lists.debian.org/debian-security-announce/>
- Activa **Dependabot** para las GitHub Actions (Settings → Code security).
- Revisa cada cierto tiempo que `unattended-upgrades` siga funcionando en un
  sistema instalado (Parte 7).

---

## Parte 12 — Siguientes pasos

| Idea | Valor | Dificultad |
|---|---|---|
| Repositorio APT propio (`aptly` + GitHub Pages) para enviar actualizaciones de `polaris-branding` y herramientas propias | Alto | Media |
| App de bienvenida (Python + GTK): actualizar, instalar códecs, activar Flatpak | Alto | Media |
| Variante LXQt (aún más ligera) | Medio | Baja |
| Pantalla de arranque con Plymouth y menú GRUB con la marca | Medio | Media |
| Pruebas automáticas de la ISO con openQA | Alto | Alta |
| Versión ARM64 (Raspberry Pi) | Alto | Alta |

---

## Parte 13 — Solución de problemas

**`debootstrap ... mknod: Operation not permitted`**
El contenedor no tiene privilegios. Usa `make iso`, que ejecuta el contenedor
con `sudo` y `--privileged`. Un podman sin root no puede crear dispositivos.

**`E: Unable to locate package NOMBRE`**
Ese paquete no existe en Debian 13 o cambió de nombre. Búscalo en
<https://packages.debian.org/trixie/> y corrige la lista.

**El build falla en un hook**
Busca el error en `salida/build-*.log`:
`grep -n -B5 "E:\|ERROR\|\[PolarisOS\]" salida/build-*.log`.
Los hooks usan `set -e`, así que el primer comando que falle detiene el build.

**Me quedé sin espacio en disco**
`sudo podman volume rm polarisos-cache` borra la caché de paquetes. Revisa con
`df -h`.

**La ISO pesa más de 2 GB (GitHub no la acepta en Releases)**
Quita aplicaciones o firmware que no necesites. Para ver qué paquetes ocupan
más, ejecuta dentro de PolarisOS:
`dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -20`

**Sin Wi-Fi en un equipo real**
`lspci -nnk | grep -A3 -i net` y `sudo dmesg | grep -i firmware`. Agrega el
paquete `firmware-*` que corresponda en `05-firmware.list.chroot`.

**Secure Boot falla después de instalar (se queda en `grub>`)**
El GRUB firmado de Debian se construye pensando en la carpeta `EFI/debian`.
Si al probar con `secureboot --solo-disco` el sistema instalado no arranca,
haz que el gestor de arranque use el nombre "Debian" en sus dos puntos de
configuración:

1. En `config/includes.chroot/etc/calamares/branding/polaris/branding.desc`:
   ```yaml
       bootloaderEntryName: Debian
   ```
2. Crea `config/includes.chroot/etc/default/grub.d/polarisos.cfg` con:
   ```bash
   GRUB_DISTRIBUTOR="Debian"
   ```
   (sin esto, la próxima actualización de GRUB volvería a usar el nombre
   PolarisOS).

Reconstruye y repite la Parte 7. El menú de arranque dirá "Debian", pero el
sistema sigue siendo PolarisOS.

**El fondo o el tema no se aplican**
El script `polaris-first-login` corre una sola vez por usuario. Para
repetirlo: `rm ~/.config/polarisos/first-login-done` y cierra sesión.

**La VM es muy lenta**
Revisa que KVM esté disponible (`ls -l /dev/kvm`, grupo `kvm`, virtualización
activada en la BIOS).

---

*¿Encontraste un error en esta guía? Abre un issue o un pull request.*
