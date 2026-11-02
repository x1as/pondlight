# Asset licenses

All art, the bitmap font, sound effects, ambience and music in this project are **original works created for PONDLIGHT**
by deterministic generator scripts in `tools/` (Python + Pillow, pure-Python audio synthesis). No third-party images,
fonts, samples or asset packs were used, and nothing was downloaded from other games.

| Asset group | Source | Generator |
|---|---|---|
| Pond dioramas (Willow, Frostmere, Emerald Delta, Leviathan Trench), thumbnails | original | `tools/art/gen_world.py`, `gen_frost.py`, `gen_wild.py` |
| 12 procedural fish sprites (fallbacks) | original | `tools/art/gen_fish.py` |
| UI kit, icons, logo, cursor, app icon, FX sprites | original | `tools/art/gen_ui.py` |
| Pixel font "Pondlight" | original | `tools/art/gen_font.py` |
| SFX, ambience, music | original synthesis (Karplus-Strong, FM bells, filtered noise) | `tools/audio/gen_audio.py` |
| Shaders (water, fog, aurora) | original | `pondlight/assets/shaders/` |

### SpriteCook-generated assets (2026-11-02, owner's SpriteCook account, free tier, 40 credits)
Generated with SpriteCook (spritecook.ai) under the owner's account, then cleaned by `tools/art/polish_spritecook.py`
(dominant-colour downsample to the game's pixel density, palette quantize, stray-pixel removal, 1-px re-ink).
Asset IDs and file hashes: `spritecook-assets.json`. Raw downloads are kept in `pondlight/assets/art/spritecook/_raw/` and are excluded from builds.

| Asset | Used in game | Cost |
|---|---|---|
| Bobber (style anchor) | yes, hanging/flying/biting | 2 cr |
| Bobber 6-frame float loop (animate_game_art) | yes, while floating | 20 cr |
| Bluegill, River Perch, Silver Carp, Golden Tench, Moonlit Eel, Ancient Willow Pike | yes, catch card, Codex, bag, demo end screen | 6 × 2 cr |
| Reel | **no**: its painted-in crank conflicts with the animated reel feedback | 2 cr |
| Gold trophy (bronze/silver/platinum are palette swaps made by `polish_spritecook.py`) | yes, Trophy Cabinet | 2 cr |
| Old Croak, the frog guide | yes, tutorial | 2 cr |

### SpriteCook-generated assets, v0.4 (second owner account, free tier, 40 credits)
Same polish pipeline. Two of our own polished fish (Bluegill, Willow Pike) were uploaded as style references.

| Asset | Used in game | Cost |
|---|---|---|
| Frostmere fish redone: Ice Minnow, Arctic Char, Snow Whitefish, Glass Pike, Aurora Salmon, Ancient Frost Sturgeon | yes | 6 × 2 cr |
| Emerald Delta: Red-bellied Piranha, Peacock Bass, Silver Arowana, Electric Eel, Goliath Catfish, Arapaima | yes | 6 × 2 cr |
| Leviathan Trench: Bluefin Tuna, Swordfish, Anglerfish, Coelacanth, the Kraken, the Megalodon | yes | 6 × 2 cr |
| Treasure chest | yes, catch card when a chest is found | 2 cr |

Check SpriteCook's current terms of service for commercial use before shipping. 2 credits remain on the second account.

## Third-party software
* **Godot Engine 4.7.2** — MIT License, © Juan Linietsky, Ariel Manzur and Godot contributors. Exported games include Godot; ship its license
  text (https://godotengine.org/license) e.g. in a `licenses` folder or in the credits.
* Godot bundles third-party components (FreeType, etc.) under their own permissive licenses — see `Engine.get_license_info()` / the Godot `COPYRIGHT.txt`.
