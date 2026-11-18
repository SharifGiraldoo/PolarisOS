#!/usr/bin/env python3
"""
PolarisOS — genera el arte base (logo, fondo de pantalla e imágenes del
instalador) de forma reproducible. Requiere Pillow:

    sudo apt install python3-pil      # o: pip install pillow
    python3 assets/generar-arte.py

Reemplaza estas imágenes por diseños propios cuando los tengas; solo
respeta los nombres y rutas de salida.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CALAMARES = os.path.join(RAIZ, "config/includes.chroot/etc/calamares/branding/polaris")
BRANDING = os.path.join(RAIZ, "packages/polaris-branding/files")
GRUB = os.path.join(RAIZ, "config/bootloaders/grub-pc")

# Paleta: azul noche polar + blanco estelar + acento cian
FONDO_ARRIBA = (6, 12, 38)
FONDO_ABAJO = (14, 46, 84)
ESTRELLA = (255, 255, 255)
BRILLO = (120, 210, 255)


def degradado(ancho, alto):
    img = Image.new("RGB", (ancho, alto))
    pix = img.load()
    for y in range(alto):
        t = y / max(alto - 1, 1)
        color = tuple(int(a + (b - a) * t) for a, b in zip(FONDO_ARRIBA, FONDO_ABAJO))
        for x in range(ancho):
            pix[x, y] = color
    return img


def puntos_estrella(cx, cy, r_ext, r_int, puntas=4, giro=-math.pi / 2):
    pts = []
    for i in range(puntas * 2):
        r = r_ext if i % 2 == 0 else r_int
        a = giro + i * math.pi / puntas
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def dibujar_polaris(img, cx, cy, r):
    """Estrella de 4 puntas con halo: la Estrella Polar."""
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(halo)
    for i in range(6, 0, -1):
        rr = r * (0.35 + i * 0.12)
        alfa = int(28 + (6 - i) * 10)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=BRILLO + (alfa,))
    halo = halo.filter(ImageFilter.GaussianBlur(r * 0.18))
    img.paste(halo, (0, 0), halo)

    d = ImageDraw.Draw(img)
    d.polygon(puntos_estrella(cx, cy, r, r * 0.22), fill=ESTRELLA)
    d.polygon(puntos_estrella(cx, cy, r * 0.55, r * 0.15, giro=-math.pi / 4), fill=ESTRELLA)


def estrellas_fondo(img, cantidad, semilla=7):
    import random

    rnd = random.Random(semilla)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(cantidad):
        x, y = rnd.randrange(w), rnd.randrange(h)
        s = rnd.choice([1, 1, 1, 2])
        b = rnd.randint(120, 255)
        d.ellipse([x, y, x + s, y + s], fill=(b, b, b))


def fuente(tamano):
    for ruta in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    ):
        if os.path.exists(ruta):
            return ImageFont.truetype(ruta, tamano)
    return ImageFont.load_default()


def logo(tamano):
    img = Image.new("RGBA", (tamano, tamano), (0, 0, 0, 0))
    fondo = Image.new("RGBA", (tamano, tamano), (0, 0, 0, 0))
    ImageDraw.Draw(fondo).ellipse([0, 0, tamano - 1, tamano - 1], fill=FONDO_ARRIBA + (255,))
    img.paste(fondo, (0, 0), fondo)
    dibujar_polaris(img, tamano / 2, tamano / 2, tamano * 0.38)
    return img


def fondo_pantalla(ancho=1920, alto=1080, con_texto=True):
    img = degradado(ancho, alto).convert("RGBA")
    estrellas_fondo(img, int(ancho * alto / 4000))
    dibujar_polaris(img, ancho * 0.72, alto * 0.32, alto * 0.11)
    if con_texto:
        d = ImageDraw.Draw(img)
        d.text((ancho * 0.07, alto * 0.82), "PolarisOS", font=fuente(int(alto * 0.06)),
               fill=(255, 255, 255, 230))
    return img.convert("RGB")


def centrar_texto(d, y, texto, tam, color, ancho):
    f = fuente(tam)
    caja = d.textbbox((0, 0), texto, font=f)
    d.text(((ancho - (caja[2] - caja[0])) / 2, y), texto, font=f, fill=color)


def splash_grub(ancho=800, alto=600):
    """Fondo del menú de arranque (GRUB). El menú empieza al 46 % de la altura."""
    img = degradado(ancho, alto).convert("RGBA")
    estrellas_fondo(img, 90, semilla=11)
    # Panel semitransparente detrás del menú para que el texto se lea bien
    panel = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle(
        [ancho * 0.18, alto * 0.44, ancho * 0.82, alto * 0.86], radius=10, fill=(4, 9, 28, 200))
    img.alpha_composite(panel)
    dibujar_polaris(img, ancho / 2, alto * 0.20, alto * 0.10)
    d = ImageDraw.Draw(img)
    centrar_texto(d, alto * 0.30, "PolarisOS", int(alto * 0.07), (255, 255, 255, 255), ancho)
    centrar_texto(d, alto * 0.385, "Lightweight  ·  Secure  ·  Debian-based", int(alto * 0.03),
                  (142, 163, 196, 255), ancho)
    return img.convert("RGB")


def marca_plymouth(ancho=420, alto=120):
    """Marca de agua del arranque gráfico (Plymouth), fondo transparente."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    dibujar_polaris(img, alto * 0.45, alto / 2, alto * 0.36)
    d = ImageDraw.Draw(img)
    d.text((alto * 0.95, alto * 0.22), "PolarisOS", font=fuente(int(alto * 0.46)),
           fill=(255, 255, 255, 255))
    return img


def main():
    os.makedirs(CALAMARES, exist_ok=True)
    os.makedirs(BRANDING, exist_ok=True)
    os.makedirs(GRUB, exist_ok=True)

    logo(256).save(os.path.join(CALAMARES, "logo.png"))
    logo(256).save(os.path.join(BRANDING, "polarisos-logo.png"))
    fondo_pantalla(1920, 1080).save(os.path.join(BRANDING, "polarisos-fondo.png"))
    fondo_pantalla(800, 450).save(os.path.join(CALAMARES, "welcome.png"))
    splash_grub().save(os.path.join(GRUB, "splash.png"))
    marca_plymouth().save(os.path.join(BRANDING, "polarisos-plymouth.png"))
    print("Arte generado en:\n  " + CALAMARES + "\n  " + BRANDING + "\n  " + GRUB)


if __name__ == "__main__":
    main()
