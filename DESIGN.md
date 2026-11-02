# PONDLIGHT — Revised Game Design (v0.5)

> **v0.5 — juice and flow (trend-driven, see SUCCESS_FORECAST.md):**
> * **Catch tally.** The catch card builds the price chip by chip: base x rarity x size x skill x record x streak x golden x frenzy x prismatic. Each chip pops with a rising pitch and explains itself on hover.
> * **Prismatic variants.** 1% of catches (+Luck) get a holographic foil shader, x5 value and x2 mastery XP. They are counted in the codex and earn a trophy (replaces RECORD_10). This is a variant, not a rarity tier, so owner rule O5 still holds.
> * **Feeding Frenzy.** At streaks of 5, 15, 25… the water boils for 30 s: bites come x0.35 sooner, the bite window is longer and value is x1.5. A flame frame, a countdown and faster music show it.
> * **Cinematic.** Legendary, prismatic and boss catches get slow motion, cinema bars and a stamped title.
> * **Captain's Orders.** Three rolling short goals (species, habitat, rarity, perfect casts, combo, streak, tide). They pay at once and are replaced immediately. A HUD tracker shows them.
> * **Fish traps.** Every unlocked water earns coins while the game is closed (scaled by gear, up to 8 h), shown on a *Welcome back* screen.
> * **Coin flights.** Every payout flies into the counter.
> * The menu shows the water you last fished, with its music.

> **v0.4 (owner requests):**
> * **No bag.** Every catch is sold on the spot (catch card: *Sell* or *Tide of Fortune*). Old saves: fish left in the bag are sold and the Big Basket talent is refunded (save v2).
> * **Gear vs fish power.** Every species has a power; rarity multiplies it (x1.00 / 1.12 / 1.28 / 1.48 / 1.72).
>   * Rod power scales strike gain, the reel scales hold progress, line strength scales how fast tension builds, and the overall gear rating scales the target zone.
>   * Under-geared fights against rare fish are genuinely hard. Legendaries are easy only with strong gear.
>   * The hover forecast, fight panel, codex and shop show Easy / Fair / Hard / Brutal.
> * **Progression.** 10 tiers per slot, 15 talents in 5 sectors (new: Long Arm, Fish Whisperer, Angler's Might, Lucky Charm, Gambler's Nerve, Treasure Nose), 8 baits (new: River Shrimp, Deep Squid, Monster Chum, Lucky Fly). Stats and items explain themselves on hover (HoverTip).
> * **Two new waters.**
>   * **Emerald Delta** (piranha, peacock bass, arowana, electric eel, goliath catfish, arapaima).
>   * **Leviathan Trench** (bluefin tuna, swordfish, anglerfish, coelacanth, **the Kraken**, **the Megalodon**).
>   * Wilder waters start further out (`reach_offset`), so the far Abyss needs the best rods.
>   * Simulated pace for an efficient player who ignores talents: Frostmere about 0.4 h, Delta about 3 h, Trench about 9 h, both legends about 13–14 h.
> * **Tide of Fortune.** A unique push-your-luck: ride a catch's coin value on up to 3 waves (x0–x3) by stopping a sweeping bobber. In-game coins only (see IP_AND_RATINGS.md).
> * **Treasure chests.** About 3% of catches also bring up a chest (coins, a jackpot or bait packs).
> * **Trophies.** Still 25 + the platinum grand trophy, re-balanced across all four waters (Kraken, Megalodon, High Tide, Treasure Hunter, …).
> * **Demo removed.** One build only.
> * SpriteCook (second account, 40 credits): 18 fish (all of Frostmere redone, plus 12 new) and the treasure chest, 38 credits.

> **v0.3:**
> * **Russian language.** Hand-drawn Cyrillic pixel glyphs and ~410 translated strings (`data/locale/ru.json`). Auto-detected from the OS and switchable in Settings.
> * **Centred UI.** `UIButton` centres icon + caption as one group; labels are vertically centred; the font baseline is optically centred; panels re-centre when translations make them wider.
> * **Juice.** Outlined punch pop-text for PERFECT/GOOD/MISS/COMBO, spark bursts and rings, hit-stop on PERFECT, shakes, and a rare-catch celebration (flash, rays, confetti, rarity banner) that respects Reduced flashing.
> * **Talents.** 4 sectors (Casting, Patience, Fighting, Trade & Study), 11 talents × 5 levels, all speeding up progress.
> * **Trophy cabinet.** 25 trophies in bronze/silver/gold plus the platinum "Master of Pondlight" grand trophy for collecting all 25.
> * **Hand-held tutorial.** Old Croak the frog walks a new player through one guaranteed, gentle catch, then points at the Shop.
> * **New ideas.** A **hot streak** (+2% sale value per catch in a row, up to +20%) and **golden spots** (a sparkling cell for 40 s: +4 mastery levels to the rarity roll, ×1.5 value).
> * SpriteCook: gold trophy (recoloured into 4 tiers) and the frog guide, using the account's last 4 credits.

> **v0.2 (2026-11-02) applies the owner's "Overriding product, art and business requirements" brief.** Changes vs v0.1:
> * Rarity curve now uses the published anchors exactly (L1 65/25/8/1.8/0.2 · L5 48/28/16/7/1 · L10 28/28/24/15/5 · L15 12/18/25/27/18 · **L20 0/0/5/45/50**), monotone-cubic interpolation between anchors, Luck capped at a 3 pp shift from Common/Uncommon (cannot raise L20 Legendary above 50%).
> * Ponds rebuilt on an **8×6 logical grid** (60×42 / 60×40 px cells) covering ≈70% of the play area; new habitat **Roots & Timber**; sharper habitat affinities so different cells are led by different species.
> * Hover forecast shows **likelihood tiers** per species (exact % only after you've caught that species 3 times), separate from the rarity roll; **F / R3 habitat view** labels every cell.
> * Mastery XP bonuses (discovery / record / new rarity, capped per catch); catch card shows XP and the habitat it came from; Codex shows base and Luck-adjusted rarity odds.
> * Instant input: every press moves the rod immediately; presses inside the 70 ms strike cooldown are buffered, never dropped; rod spring speed capped (no tip teleport under spam).
> * First-session coaching line and a gentler first fight.
> * **+1 step: Steam demo build** (`Windows Demo` preset, `demo` feature tag): Willow only, own save file, end-of-demo recap + wishlist CTA.
> * Business deliverables: STEAM_MARKET_RESEARCH.md, BUSINESS_MODEL.md, STEAM_MARKETING_PLAN.md.
> * SpriteCook (v0.2.1): new account with 40 credits. Generated the bobber anchor, its 6-frame float animation and the 6 Willow fish. The full UI kit (~40–60 cr) and tilesets did not fit the budget; procedural art stays for those and for Frostmere fish. See ASSET_LICENSES.md.

> This document **overrides** the original master prompt wherever they disagree.
> Order of authority: (1) owner corrections → (2) Steam business-analysis corrections → (3) original master prompt.

---

## 1. Owner corrections (highest priority)

| # | Correction | How it is implemented |
|---|---|---|
| O1 | **UI is wooden-forest style**, saturated greens, grass & leaves rich and vivid | Hand-drawn wood plank panels, parchment inserts, leaf corner ornaments, saturated green palette (`ART_BIBLE.md`). No default Godot controls — every Control is skinned by `UITheme`. |
| O2 | **Everything should look like it was drawn in Aseprite** | Pure pixel art at 640×360, integer scaling, nearest filtering, hand-tuned palette, 1-px outlines, ordered dithering, cluster shading. Own bitmap font. |
| O3 | **Minimal animations, but ultra quality** | Few animated elements, each tuned: rod spring-bend, line sag/tension, bobber states, pixel water shimmer shader, ripples, splashes, weather. No gratuitous bouncing UI. |
| O4 | **Ponds are grids of cells in the middle of the screen**, each cell has its own conditions (moss shade, tree shade, reeds, lily pads, deep water, rocks…) and its **own catch percentages** | Hidden 14×7 grid per pond, data-driven layout string. Every spot type has per-species affinity → every cell has a different fish distribution. Hover/cursor shows the cell's odds. |
| O5 | **6 fish per pond; every fish can be caught at any rarity Common → Legendary** (rarity is per *catch*, not per species). **Mythic tier removed.** | 5 rarity tiers: Common, Uncommon, Rare, Epic, Legendary. Rarity rolled after the species. |
| O6 | **Each fish species has its own level (max 20).** Higher level → higher chance of higher rarity. **At level 20: 50 % Legendary, 45 % Epic, 5 % Rare** (v0.2 brief) | Species *Mastery* level 1–20, XP from catching that species only. Exact anchors in `balance.json → rarity_table.anchors`, monotone-cubic interpolation, unit-tested. |
| O7 | **The rod and the fishing process are the #1 sprite / feel priority**: smooth, but snappy when the player spams; the line must be clearly visible | Rod is drawn every frame from a spring simulation (bend reacts instantly to taps, settles smoothly), tier-specific materials, cork grip, spinning reel crank, guides; line is a 1-px sagging curve that tightens and reddens with tension. |
| O8 | **Fish do not need to be animated in the pond**; the pond itself must be beautiful | No swimming fish sprites. The water is animated (shader), bites are telegraphed by bobber, ripples and bubbles. Fish sprites appear only on catch / codex. |
| O9 | Use SpriteCook skills for UI / sprites / animation | Investigated: SpriteCook account had 2 credits (free tier) — a UI kit costs ~30-60. Owner chose: **all art hand-authored as pixel art through Python/Pillow scripts** (`tools/art`). Assets are regenerable and can later be replaced by SpriteCook output with the same file names. |

## 2. Steam business-analyst corrections

**Positioning.** Cozy incremental fishing, premium, offline, no MTX. Comparable Steam niche: small cozy/idle-adjacent fishing & collection titles that sell on "one more catch" loops and achievement hunting. Target price **$4.99–$6.99**, 3–6 h to 100 % for the MVP content, expandable with ponds as updates/DLC.

| # | Change vs. master prompt | Reason |
|---|---|---|
| B1 | **First catch in < 45 s** from New Game, no blocking tutorial; contextual hints only | Steam refund window = 2 h; Steam reviews punish slow openings. |
| B2 | Rarity per catch + species mastery (O5/O6) replaces fixed-rarity species | Gives every species long-term value; 6 species × 5 rarities = **30 codex entries per pond** → collection depth without art cost. |
| B3 | **Pond unlock = all 6 Willow species discovered (any rarity) + 2,500 coins** (master prompt suggested 3,000) | The 30-player balance simulation in `tests/` puts the unlock at a median of ~32 min of *efficient* play (≈40–55 min for a typical player, who reads tooltips and browses menus) — inside the 2-hour refund window with room for early upgrades. |
| B4 | **Bad-luck protection** for undiscovered species + cell-odds visible on hover | "Blind RNG" is the #1 complaint in fishing-game reviews. |
| B5 | **Daily challenges are optional bonuses, never FOMO** (no streak loss, no missable content) | Premium Steam audience reacts badly to mobile-style dailies. |
| B6 | Weather/time **only bias** odds, never gate a species | Avoids "wait 20 minutes for night" frustration. |
| B7 | **Reach** is the visible reason to upgrade the rod: far rows (shade, deep water) need a better rod | Upgrades must change *where* you can fish, not just numbers. |
| B8 | Steam Deck friendly: full gamepad loop, 16:9 internal res with integer scaling, readable 8-px font at 2× | Deck "Playable/Verified" boosts discoverability. |
| B9 | **Achievements data-driven** behind `PlatformService` (local now, Steamworks later). 14 achievements | Achievement hunters are a core cozy-game audience. |
| B10 | Settings: master/music/sfx/ambient, fullscreen, window scale, screen shake, reduced flashing | Standard Steam expectations; accessibility. |
| B11 | Mythic tier removed; the "special feeling" is carried by Legendary + level-20 mastery stars | Simpler rarity language; matches owner's O5. |
| B12 | Scope cut: no remapping UI in MVP (fixed, documented, Steam Input compatible bindings) | Steam Input handles remapping on Steam; reduces risk. |

## 3. Core loop

1. Pick a cell on the pond grid (mouse hover / stick cursor). The tooltip shows spot type and **that cell's odds** (discovered species named, others `???`).
2. Hold to charge the cast → release in the **Perfect** zone for a precise cast and better bite.
3. Wait (5–12 s typical), watch nibbles; on the real **bite** press within the window to hook.
4. **Fight**: timing-strike (tap when the marker is in the zone) + hold-to-reel, release during **SURGE**. Progress to 100 % before tension maxes or time runs out.
5. Catch → species, **rarity**, weight, value, record flags, mastery XP.
6. Sell / keep in bag → coins → upgrade Rod / Reel / Line / Charm, buy bait.
7. Discover all 6 species → unlock Frostmere Lake → repeat with harder fish.

## 4. Systems summary

* **Stats**: POWER (reach rows + progress per strike), REEL (progress per second when holding), CONTROL (zone width, tension decay), LINE (max tension), LUCK (rarity weight shift + better specimen size).
* **Equipment**: Rod, Reel, Line, Charm — 5 tiers each, before/after preview in shop.
* **Bait**: Worm (free), Golden Larva (rarity +3 mastery levels, rare species ×), Moss Grub (shade/moss lovers ×, faster bites), Frost Bait (Frostmere only: faster bites, rarity +2 levels).
* **Rarity** (per catch): weight exponent, value multiplier, fight difficulty, final burst on Epic/Legendary.
* **Fish states**: CALM, STRUGGLE, SURGE (telegraphed), RECOVERY, FINAL_BURST.
* **Time of day** (12 real-minute day) and **weather** (clear/rain at Willow, clear/snow at Frostmere).
* **Save**: versioned JSON, atomic write (tmp → rename), `.bak` recovery, autosave after every important event.

All numbers live in `pondlight/data/*.json`.
