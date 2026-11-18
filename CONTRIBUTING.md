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
- **Mensajes de commit** en español y en modo imperativo:
  `Agrega soporte para impresoras`, `Corrige el fondo en monitores 4K`.
