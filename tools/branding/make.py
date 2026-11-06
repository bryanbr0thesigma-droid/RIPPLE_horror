# Builds every image in docs/BRANDING_REQUESTS.txt and checks each one's size and transparency
# against the request. Writes the PNGs and a contact sheet (contact_sheet.png) to <out_dir>.
#   python3 make.py <out_dir>
import os, sys
from PIL import Image, ImageDraw, ImageFont

import brands, lobby, facility

# name: (width, height, transparent background?)
SPEC = {
    "falcon_logo_full": (2048, 1024, True), "falcon_logo_onecolor": (1024, 1024, True),
    "soda_front": (512, 1024, False), "soda_side": (512, 1024, False),
    **{f"pamphlet_{i}": (256, 512, False) for i in range(1, 7)},
    **{f"poster_{i}": (768, 1024, False) for i in range(1, 5)},
    **{f"magazine_{i}": (512, 680, False) for i in range(1, 4)},
    "coffee_label": (512, 256, False), "station_sign": (1024, 256, False), "notice": (512, 512, False),
    "keyfob": (128, 256, False), "signin_page": (512, 512, False), "mail_note": (256, 256, False),
    "door_decal": (512, 512, True), "neon_design": (1024, 512, True), "clock_face": (512, 512, True),
    "rug_logo": (512, 512, True), "electronics_logo": (512, 128, True),
    "training_sign": (1024, 640, False), **{f"room_title_{i}": (1024, 256, True) for i in range(1, 8)},
    "noise_meter": (512, 256, True),
    **{f"sign_{k}": (512, 512, False) for k in ("no_diving", "no_running", "staff_only", "deep_water", "no_drinking")},
    **{f"label_{k}": (512, 256, False) for k in ("generator", "distiller", "charger", "cover")},
    "exit_sign": (512, 256, False), "halls_plaque": (1024, 640, False),
    "ripple_logo": (2048, 1024, True), "menu_header": (1024, 256, True),
}


def check(out):
    bad = []
    for name, (w, h, transparent) in SPEC.items():
        p = os.path.join(out, name + ".png")
        if not os.path.exists(p):
            bad.append(f"{name}: missing")
            continue
        im = Image.open(p)
        if im.size != (w, h):
            bad.append(f"{name}: {im.size}, wanted {(w, h)}")
        has_alpha = im.mode == "RGBA" and im.getchannel("A").getextrema()[0] < 255
        if transparent != has_alpha:
            bad.append(f"{name}: transparent={has_alpha}, wanted {transparent}")
    return bad


def contact_sheet(out):
    cell, pad, cols = 300, 16, 8
    names = list(SPEC)
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + 40 + pad) + pad), (52, 56, 64))
    fnt = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 15)
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = Image.open(os.path.join(out, n + ".png")).convert("RGBA")
        im.thumbnail((cell, cell), Image.LANCZOS)
        bg = Image.new("RGBA", im.size, (96, 104, 116, 255))       # transparent ones show on grey
        bg.alpha_composite(im)
        x = pad + (i % cols) * (cell + pad)
        y = pad + (i // cols) * (cell + 40 + pad)
        sheet.paste(bg.convert("RGB"), (x + (cell - im.size[0]) // 2, y + (cell - im.size[1]) // 2))
        d.text((x + cell / 2, y + cell + 18), n + ".png", font=fnt, fill=(230, 230, 230), anchor="mm")
    sheet.save(os.path.join(out, "contact_sheet.png"), optimize=True)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    brands.run(out)
    lobby.run(out)
    facility.run(out)
    problems = check(out)
    print("\n".join(problems) if problems else f"all {len(SPEC)} images match the requested sizes")
    contact_sheet(out)
