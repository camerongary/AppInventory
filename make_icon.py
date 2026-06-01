#!/usr/bin/env python3
"""Generate the App Inventory icon: a clipboard holding a sheet of paper with a checklist."""
from PIL import Image, ImageDraw

S = 4               # supersample factor for smooth edges
SIZE = 1024 * S


def rr(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# --- Squircle background with vertical blue gradient -------------------------
margin = 100 * S
body = SIZE - 2 * margin
radius = int(0.2237 * body)
top_c = (90, 169, 230)      # light blue
bot_c = (39, 110, 184)      # deeper blue

grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gdraw = ImageDraw.Draw(grad)
for y in range(margin, margin + body):
    t = (y - margin) / body
    gdraw.line([(margin, y), (margin + body, y)], fill=lerp(top_c, bot_c, t) + (255,))
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    [margin, margin, margin + body, margin + body], radius=radius, fill=255)
img.paste(grad, (0, 0), mask)

# subtle top sheen
sheen = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(sheen).rounded_rectangle(
    [margin, margin, margin + body, margin + int(body * 0.5)],
    radius=radius, fill=40)
white = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
img.paste(white, (0, 0), Image.composite(sheen, Image.new("L", (SIZE, SIZE), 0), mask))

draw = ImageDraw.Draw(img)

# --- Clipboard board --------------------------------------------------------
cb_w = int(560 * S)
cb_h = int(680 * S)
cb_x = (SIZE - cb_w) // 2
cb_y = int(250 * S)
cb_r = int(46 * S)
# drop shadow
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle(
    [cb_x, cb_y + 14 * S, cb_x + cb_w, cb_y + cb_h + 14 * S], radius=cb_r,
    fill=(0, 0, 0, 70))
img.alpha_composite(shadow)
draw = ImageDraw.Draw(img)
rr(draw, [cb_x, cb_y, cb_x + cb_w, cb_y + cb_h], cb_r,
   fill=(198, 138, 82), outline=(150, 100, 54), width=4 * S)

# --- Paper sheet ------------------------------------------------------------
pad = int(46 * S)
pp_x = cb_x + pad
pp_y = cb_y + int(78 * S)
pp_w = cb_w - 2 * pad
pp_h = cb_h - int(78 * S) - pad
rr(draw, [pp_x, pp_y, pp_x + pp_w, pp_y + pp_h], int(20 * S),
   fill=(255, 255, 255), outline=(225, 227, 230), width=2 * S)

# --- Metal clip -------------------------------------------------------------
clip_w = int(180 * S)
clip_h = int(96 * S)
clip_x = (SIZE - clip_w) // 2
clip_y = cb_y - int(48 * S)
rr(draw, [clip_x, clip_y, clip_x + clip_w, clip_y + clip_h], int(34 * S),
   fill=(176, 182, 188), outline=(120, 126, 132), width=3 * S)
# inner notch
notch_w = int(96 * S)
notch_h = int(40 * S)
nx = (SIZE - notch_w) // 2
ny = clip_y + int(14 * S)
rr(draw, [nx, ny, nx + notch_w, ny + notch_h], int(18 * S), fill=(210, 214, 218))

# --- Checklist rows ---------------------------------------------------------
rows = 4
box_sz = int(70 * S)
row_gap = int(118 * S)
left = pp_x + int(46 * S)
first_y = pp_y + int(70 * S)
line_x0 = left + box_sz + int(40 * S)
line_x1 = pp_x + pp_w - int(46 * S)
green = (52, 199, 89)
gray = (200, 205, 210)

for i in range(rows):
    by = first_y + i * row_gap
    # checkbox
    rr(draw, [left, by, left + box_sz, by + box_sz], int(16 * S),
       fill=(255, 255, 255), outline=green, width=6 * S)
    # checkmark
    draw.line(
        [(left + int(16 * S), by + int(38 * S)),
         (left + int(30 * S), by + int(52 * S)),
         (left + int(56 * S), by + int(18 * S))],
        fill=green, width=11 * S, joint="curve")
    # text line
    ly = by + box_sz // 2
    draw.rounded_rectangle(
        [line_x0, ly - int(14 * S), line_x1, ly + int(14 * S)],
        radius=int(14 * S), fill=gray)

# --- Downsample -------------------------------------------------------------
out = img.resize((1024, 1024), Image.LANCZOS)
out.save("icon_1024.png")
print("wrote icon_1024.png")
