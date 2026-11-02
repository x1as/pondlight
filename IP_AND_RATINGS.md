# PONDLIGHT — IP and age-rating check (v0.4, 2026-11-02)

This is a practical self-check, not legal advice. Before launch, have a lawyer look at the name and the store page, and complete Steam's content survey and IARC questionnaire honestly.

## 1. Name
* A web search on 2026-11-02 found no Steam game called **Pondlight**. Similar but different titles: *Pond* (idle pond builder, 2025), *Pondlife*, *Serene Ponds*, *Pondlings*.
* Still to do before buying store assets: search the trademark databases (EUIPO eSearch, USPTO, WIPO Global Brand Database, Rospatent) for "Pondlight" in class 9 (software) and class 41 (entertainment), and check that the domain and Steam/Twitter handles are free.

## 2. Mechanics and ideas
* Game mechanics are not copyrightable: casting meters, timing bars, rarities, upgrade trees and collection logs are genre conventions. Copying another game's **specific expression** (art, text, UI layout, level design, names) is what creates risk. PONDLIGHT does none of this:
  * All art is original: Pillow generators in `tools/art`, plus SpriteCook images made from our own prompts and our own style references.
  * All audio is original procedural synthesis (`tools/audio`).
  * All text is our own.
* The Steam market research (`STEAM_MARKET_RESEARCH.md`) lists the closest competitors. Their signature systems are different from ours: auto-fishing desktop companions, aquariums, gacha pearls, boat incremental loops.
* **Our own hooks:**
  * Grid-cell habitats with visible odds.
  * Per-species mastery to Level 20, with rarity rolled per catch.
  * Gear power against fish power.
  * The **Tide of Fortune** push-your-luck wave bar.
  * Golden spots, hot streaks and the frog guide.
* Fish: real species (piranha, arapaima, coelacanth, bluefin tuna and others) are facts of nature, free for anyone to use.
* The **Kraken** is Scandinavian folklore, and the **Megalodon** is a real extinct shark. Both are public domain.
* We avoid trademarked depictions: no "Jaws", no franchise names, no lookalike logos.
* The trophy names "Release the Kraken" and "Jaws of the Deep" are short common phrases. To remove any doubt, they can be renamed in `data/achievements.json`.

## 3. The gambling element (Tide of Fortune)
* **What it is.** After a catch, the player may risk that fish's **in-game coin value** on up to three "waves", stopping a sweeping bobber on segments worth x0 / x1 / x1.5 / x2 / x3.
* **No real money anywhere.** Coins cannot be bought, there are no microtransactions and no loot boxes, and nothing can be cashed out or traded.
* **Ratings risk.** PEGI rates *simulated gambling* (games that imitate casino or betting games) as **PEGI 18** (e.g. Balatro's initial rating). Since June 2026, *paid* random items carry PEGI 16 or more. Our design keeps away from both:
  * no cards, dice, slot reels, roulette wheels, chips or casino visuals; it is a fishing wave and bobber;
  * it is skill-influenced (a timing stop) and optional;
  * nothing is paid.

  An age rater may still call it "simulated gambling". If a rating board flags it, `data/balance.json → tide` can be set to `"rounds": 1` or the button hidden, without touching saves.
* **Treasure chests** are free random rewards found while fishing. They are never bought and are not loot boxes.
* **Steam.** Valve forbids real-money gambling and trading of in-game items for value. Neither exists here.
* **Survey answers.** On Steam's content survey and in IARC, answer the "simulated gambling" question truthfully: "players can wager in-game currency earned in play; no real money".

## 4. Third-party assets and tools
* **SpriteCook:** the images were generated on the owner's account. Re-read SpriteCook's current terms for commercial use before shipping, and keep `spritecook-assets.json` (asset IDs and hashes) as proof of origin.
* **Godot Engine (MIT):** include the license text in the credits.
