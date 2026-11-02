# PONDLIGHT — Art Bible

**Direction: handcrafted atmospheric pixel-art diorama.** Everything must look like it was placed by hand in Aseprite:
1-px outlines, cluster shading, ordered dithering only on gradients, a closed palette, no blur, no sub-pixels.

## Canvas & technical rules
* Logical canvas **640×360**, stretch mode `viewport`, aspect `keep`, **integer scale only** (2× = 1280×720, 3× = 1080p, 6× = 4K).
* Nearest filtering everywhere (`default_texture_filter = Nearest`), snap transforms & vertices to pixels.
* Never scale art by non-integer factors. UI icons are 12×12, rarity gems 8×8, cursor 10×13 (exported at 1-4×).
* Runtime-drawn elements (rod, line, ripples, weather, cursor, meters) are rasterised at the same 640×360 grid with whole-pixel coordinates.
* Font: original 5×7 bitmap font with 2-px descenders (`assets/fonts/pond_font.fnt`), 10 px base size, used at 10 or 20 (2×). Drop shadow 1 px, never outlines.

## Palette (from `tools/art/pxlib.py`)
| Ramp | Colours | Use |
|---|---|---|
| Greens g0–g9 | `#0b2418 #123821 #18502a #1f6a31 #2a8536 #3aa23b #56c043 #86dc4c #bdf06a #e6fb9a` | grass, canopies, moss, lily pads — saturated on purpose |
| Earth e0–e7 | `#1f130c … #ecd2a0` | banks, trunks, paths |
| Wood w0–w6 | `#2a170c … #e8b86f` | UI frames, dock, buttons |
| Parchment p0–p4 | `#fff6dc … #9a7a4c` | codex pages, catch card |
| Water a0–a8 | `#082a35 … #c4f5e2` | Willow water depth ramp + shimmer |
| Snow n0–n9 / Ice i0–i7 | `#141c38 … #ffffff` / `#0a2a3e … #e2f8ff` | Frostmere |
| Pine q0–q5 | `#0a1f22 … #3a8a74` | Frostmere conifers |
| Gold | `#7a4a12 #c07a1c #f2a531 #ffd04a #fff0a0` | coins, perfect zones, legendary |
| Rarity | Common `#d6dccf`, Uncommon `#7fe36a`, Rare `#4fb6ff`, Epic `#c983ff`, Legendary `#ffbe3d` | gems, names, sparkles |

## Lighting & perspective
* Top-down with a slight ¾ tilt: we look **from the south**. South-facing faces are visible: the far (north) pond bank shows a 3-px earth wall; ice holes show their far inner wall.
* Light comes from the **upper-left**. Highlights top-left, shadows bottom-right; trees cast offset shadows (+6..+14 px down-right) onto grass *and* water.
* Time of day is a multiply overlay (dawn peach → white day → amber dusk → blue night). Light sources (fireflies, lanterns, aurora) are drawn **after** the overlay so they glow.

## Environment rules
* Each pond is an **8×6 logical grid** (Willow 60×42 px cells, Frostmere 60×40) centred under the top HUD, ≈70% of the play area; the dock cells ("D") are land so the pier grows out of the shore.
* Pond shapes are derived from the data grid, then blurred + noise-thresholded → organic shoreline; never rectangles.
* Grid lines are never drawn. Cell selection = four pixel corner brackets + 10 % tint, gliding between cells.
* Every spot type must be readable by eye: roots & timber (gnarled brown roots + half-sunken branch), moss mats (lime clusters), lily pads (with notch + veins, some flowers), reeds/cattails, sunken rocks (dark shapes under the shimmer + breaching stones), willow shade (fronds + darker water), deep water (darker ramp, submerged weeds).
* Water animation lives only in `water.gdshader`: blinking 2–5 px shimmer dashes, dithered swell, lapping foam. Fish are not animated in the pond (owner rule); activity is shown with bubbles, rings and the bobber.

## Animation standards (few, but polished)
* Rod: damped spring (k 150, damping 13) — taps add impulses (snappy), it settles smoothly; tension sets the bend; idle breathing.
* Line: 1-px quadratic sag that tightens with tension, reddens above 72 %, vibrates above 80 %.
* Bobber: hangs and swings from the tip, arcs on cast, bobs ±1 px, dips on nibbles, sinks row-by-row on the bite.
* UI: 0.14–0.22 s fades/slides (quartic ease-out), count-up coins, sparkles for Epic/Legendary catches. Nothing loops just to move.
* Respect *Reduced flashing* (no strobing) and *Screen shake* settings.

## UI style
Wood plank frames with brass nails and a leaf-and-blossom sprig on the top corners; dark-wood plates for HUD/tooltips;
parchment for reading surfaces; green buttons = primary action; gold = money/perfect; red = danger. 9-slice margins: panel 14, header 10, button 5, plates 4.

## Biome identities
* **Willow Pond** — warm, lush, saturated greens, turquoise water, big weeping willow, lilies, reeds, moss, rocks, fallen log, wooden dock, falling leaves, fireflies at night, rain.
* **Frostmere Lake** — cold blues/whites, sky band with mountain ranges, dense snowy pine treeline, cracked frozen lake with 12 cut ice holes (shovelled snow rims, tip-up flags), lantern-lit walkway, red ice-fishing hut, snowfall, drifting fog, aurora curtains at night.

## Fish
12 original side-view sprites, each with its own silhouette (profile curve, hump, nose, tail type), fin layout, pattern and special features
(bluegill ear flap, perch bars & spiny dorsal, carp barbels, tench red eye & round fins, eel continuous fin, pike duckbill & rear dorsal,
translucent minnow, char spots & white fin edges, whitefish small mouth, glass pike visible skeleton, aurora salmon iridescent bands & kype, sturgeon scutes & snout).
Undiscovered fish are shown as dark silhouettes.

## Naming
`assets/art/world/<pond>/{water,flow,ground,props,canopy,sky,thumb}.png`, `assets/art/fish/fish_<id>.png`,
`assets/art/ui/{panel_*,btn_*,bar_*}.png`, `assets/art/ui/icons/{icon_*,gem_*}.png`, `assets/art/fx/*.png`. Snake_case, ids match `data/*.json`.
