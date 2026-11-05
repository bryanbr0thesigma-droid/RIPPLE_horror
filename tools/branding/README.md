# RIPPLE branding

The art asked for in `docs/BRANDING_REQUESTS.txt` (on the `claude/admiring-ride-o5042e` branch): 50
PNGs for the lobby, the training annex, the Shallow Halls and the title screen, at the sizes asked
for, in the F.A.L.C.O.N. house style of the tape and its labels. Everything is flat 2D, like the
motion graphics in the tape: drawn by code, with no AI-generated art and no photos. See `CREDITS.md`
for the few public-domain/CC0 pieces and the fonts.

```
python3 make.py <out_dir>
```

This writes every image, checks each one's size and transparency against the request, and makes
`contact_sheet.png`. Needs Python 3 with numpy and Pillow, and the Liberation, FreeFont and Inter
fonts (the other fonts are in `fonts/`).

## The names

| | |
|---|---|
| Field station | **Pinewater Field Station** (visitor reception) |
| Soda | **DEEP END**: "Take the plunge!" / "Refreshingly bottomless." |
| Coffee | **HIGH & DRY** Coffee: fine ground, "Always on dry ground." |
| Magazine | **VACANCY**: America's roadside travel monthly (July 1993, October 1993, February 1994) |
| Electronics | **TELLURIC** |

## Files

- `kit.py`: house colours, fonts, paper / photocopy / wear textures, the seal (from the tape's
  `gfx.py`), the one-colour seal, ISO-style prohibition and warning signs, pictograms.
- `brands.py`: PART 1, the F.A.L.C.O.N. logo files and the made-up brands (soda machine panels,
  coffee label, magazines, electronics logo).
- `lobby.py`: PART 2, pamphlets, posters, the station sign, the certificate, key fob, sign-in book,
  memo, door decal, neon, clock face and rug.
- `facility.py`: PARTS 3 to 5, the training sign template, room titles, noise meter, warning
  signs, equipment plates, exit sign, the Shallow Halls plaque, the RIPPLE logo and the menu header.

The warning signs are `sign_no_diving`, `sign_no_running`, `sign_staff_only`, `sign_deep_water`
and `sign_no_drinking` ("Do not drink the water", from the tape). The room titles are
`room_title_1` to `room_title_7`, and the electronics logo is `electronics_logo`.
