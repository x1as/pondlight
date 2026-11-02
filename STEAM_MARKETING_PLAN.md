# PONDLIGHT — Steam marketing & validation plan

> **v0.4 note:** the separate demo build was removed by the owner. The demo-based gates below (4, 7) now apply to a Steam Playtest or a free-weekend instead; everything else stands.

## Positioning

**Differentiation statement:** *PONDLIGHT is a cozy pixel-art fishing game where you read the pond. Shade, moss, roots, reeds, lilies, stones and deep water each attract different fish. You cast exactly where you aim, then fight with a rod you can feel bend and a line you can watch tighten. Every species has its own mastery, so even a humble Bluegill can become Legendary.*

**Target player:**
- Plays Cast n Chill, Fishing Inc, Stardew-style fishing or idle fishers, and wants something more hands-on than idle but calmer than a sim.
- Values collection logs, visible progress and short sessions.
- Often plays on a Steam Deck or with a controller.
- Buys at around $5 during a launch discount.

**Store page pillars (in this order):** 1) the rod/line fight GIF, 2) the habitat forecast, 3) per-species mastery to Legendary, 4) two hand-drawn ponds (summer forest and frozen lake with aurora), 5) offline, no microtransactions, full controller support.

**Capsule/trailer rules:** show the rod, the line and a fish bite in the first 3 seconds. No logo-only opening. Use real gameplay, captured at 3×/4× integer scale.

## Validation sequence and go / iterate / stop gates

The gates below are **our own targets**, chosen because we found no credible universal benchmarks for small fishing games. Each gate names the metric source. Adjust them after the first measurements, not before.

| Step | What | Measure (source) | Go | Iterate if | Stop/rethink if |
|---|---|---|---|---|---|
| 1. Internal prototype | Willow Pond, one rod, full cast→bite→fight→catch loop. **Done in this repo** | Team play + test suite | Loop is fun for the team at 30 min | — | — |
| 2. External playtest | 8–15 target players, observed (stream or video call), no help after the first minute | Notes: voluntary repeat casts after the task ends; first point of confusion; "did you notice habitats?" | ≥ 2/3 keep casting ≥ 10 min unprompted, and ≥ half mention habitats or rod feel unprompted | Confusion clusters on one step → fix onboarding/UI and re-test | Players stop within 5 min and nobody mentions the hook → change the hook before any content |
| 3. Coming Soon page | Capsule, trailer, 5+ screenshots, positioning above | Steamworks traffic → wishlist conversion, per traffic source | Steady organic wishlist growth after the launch spike | Low conversion from *qualified* traffic → redo capsule/first GIF | — |
| 4. Public demo (outside Next Fest) | `build/windows_demo/PondlightDemo.exe`, Willow only, ends with a wishlist screen | Steamworks demo players, median playtime, wishlists from the demo page; in-game end-screen reach | Median demo time ≥ 20 min, demo → wishlist visibly higher than page average | Short sessions → fix onboarding/first fight | Demo players don't wishlist at all → hook or presentation problem |
| 5. Wishlist tracking | UTM links per channel (Reddit, TikTok/Shorts, creators, devlog) | Steamworks wishlist adds/deletes per source, weekly | Wishlist velocity trending up week over week | Single-source dependency → diversify | Flat for 6+ weeks after content pushes → reconsider scope/launch |
| 6. Creator & community | 30–60 s clips: perfect cast, rod bending under a surge, Legendary reveal, "this cell = eels" discoveries, mastery level-up | Views → page visits → wishlists (UTM) | Clips that convert get remade in new variants | — | — |
| 7. Steam Next Fest (once only) | Use **only** when the demo already passed gate 4 and launch is ≤ 3 months after the Fest | Steamworks Fest report | — | — | Never spend the single entry on an unproven demo |

Wishlist targets come from BUSINESS_MODEL.md: ~7k–15k launch wishlists for a 1M ₽ developer-receipt year. Valve says wishlists *can be an important factor* for placement and triggers launch/discount e-mails. Purchases and play after launch still drive ongoing visibility (sources in STEAM_MARKET_RESEARCH.md).

## Channels (honest, relevant only)
- r/CozyGamers, r/incremental_games (respect self-promo rules: devlog value first), r/IndieDev / r/pixelart for art posts, fishing-game Discords, Steam Deck communities.
- Creators: cozy/idle/collector YouTubers and Twitch streamers who covered Cast n Chill, Fishing Inc and Idle Waters. Send keys with a 2-line pitch and the best GIF.
- Steam events: genre fests that fit (cozy, fishing, pixel) once the demo exists.
- Devlog: "how the pond decides which fish bites" and "making a rod feel alive" are the two strongest technical stories.
- Do not spam unrelated communities. Do not buy wishlists or reviews. Do not use "made with AI" as a selling point.

## Launch plan (once the gates are passed)
1. Coming Soon page + demo live, 3–6 months before launch.
2. Next Fest only if the demo is proven (gate 4). Submit the demo build 3–5 weeks before the Fest (Steamworks rule).
3. Launch at $4.99 with a 10–15% launch discount. Price final only after playtest session data (≥ 3 h of good play → keep $4.99; otherwise $3.99 or add content first).
4. Post-launch: fix-forward patches in week 1. A third pond as the first content update only if reviews ask for more content rather than better core.
5. Monthly: re-run BUSINESS_MODEL.md with real Steamworks data.

## Assets the game can already produce
The QA screenshot mode (`--shot … --demo=charge|bite|fight|catch --hour=… --weather=…`) renders store-ready 640×360 frames. Upscale them by an integer factor for capsules and screenshots. The demo build (`PondlightDemo.exe`) has its own save file and end-of-demo wishlist screen. Fill `data/store.json → store_url` with the real store link once the page exists.
