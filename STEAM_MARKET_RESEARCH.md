# PONDLIGHT — Steam market research

**Observation date for all store data: 2026-11-02** (pages fetched that day; prices are USD storefront unless marked RUB).
Labels: **[Steam]** = official Steam store/Steamworks page · **[Reviews]** = public Steam review counts · **[3rd-party]** = third-party data or estimate · **[Assumption]** = our own.

## 1. Direct and adjacent competitors

| Game (App ID) | Price | Release state | Reviews [Reviews] | Core loop & style | Selling points / content | Differentiators & notes |
|---|---|---|---|---|---|---|
| **Idle Waters** (2963540) | $4.99 (on sale $3.54, −29% until Nov 8); **200 RUB** list, 142 RUB on sale [Steam] | Released 2025-06-12 | Very Positive, 354 reviews, 94% | Idle auto-fishing desktop companion at the bottom of the screen; pixel art | 12 biomes, 100 fish, colour variants, legendary fish, upgrades, treasures, quests, aquarium customisation; demo available | Depth of content at a low price; idle/"desktop companion" positioning |
| **Cozy Catch** (3847500) | $4.99 [Steam] | Early Access since 2026-07-14 (EA "about 1–3 months") | 1 review, no score yet | Idle/active fishing, spooky-cozy tone, pixel art | Trinkets & hooks, day/night, cosmetics, fish catalogue, in-game (non-paid) "pearl gacha"; free demo (App 3868510) | English only, Windows only, **no gamepad support** listed |
| **Incremental Fishing** (4456630) | $5.49; **265.80 RUB** [Steam] | Released 2026-08-12 | Very Positive, 52 reviews, 96% | Short incremental boat/ocean fishing, cartoony 2D/3D | Upgrades, 22 languages, Supporter DLC $2.49, 15 bundles; demo | Strong localisation; small audience so far |
| **Meow Squad: Incremental Fishing** (4753960) | $5.99 [Steam] | Released 2026-09-23 | All: Very Positive 88% of 529; **recent: Mixed 50% of 22** | 30-second rounds, cats operating turrets, boss battles, 3D cartoon | 5 seas, 18 species, 120+ talents, 16 collectibles, 10 net upgrades, 13 languages | Arcade/boss hook; recent sentiment dropping |
| **Fishing Inc** (4126480) | $4.99 [Steam] | Released 2026-04-14 | Very Positive, 91% of 1,980; recent 90% of 114 | Cozy incremental, click to reach a target before the fish escapes; minimalist pixel | Multiple locations, catch log where **"your skill improves with each species"** → bigger, higher-quality fish; gear & upgrades | **Closest mechanical overlap with our per-species mastery idea** — we must not lead with mastery alone |
| **Cast n Chill** (3483740) | $14.99 [Steam] | Released 2025-06-16 | **Overwhelmingly Positive, 95% of 5,326 English reviews**; recent Very Positive 92% of 218 | Premium pixel-art fishing with active + passive (idle) modes; lakes/rivers/ocean | 16 spots, 50+ fish, 16 legendaries, cabin restoration, pet, split-screen co-op, controller | The genre's quality bar. 3rd-party review summaries mention complaints about content length, price and repetition [3rd-party] |

Other 2026 entrants seen in Steam search (not analysed in depth, store data not verified): Anglers Journey (3679600, "Q2 2026"), Stream Fishery (5505810), Far Fishing, Captain Whiskers: Incremental Seas (Nov 2025) [3rd-party search snippets].

Unit sales or revenue for these games are **not public**. Any copies estimate (e.g. "reviews × 30–60") is a third-party heuristic with wide error. We did not use it to draw conclusions.

Sources: [Idle Waters](https://store.steampowered.com/app/2963540/Idle_Waters/), [Cozy Catch](https://store.steampowered.com/app/3847500/Cozy_Catch/), [Incremental Fishing](https://store.steampowered.com/app/4456630/Incremental_Fishing/), [Meow Squad](https://store.steampowered.com/app/4753960/), [Fishing Inc](https://store.steampowered.com/app/4126480/), [Cast n Chill](https://store.steampowered.com/app/3483740/Cast_n_Chill/), RUB prices via `?cc=ru` on the same pages, [Cast n Chill review roundup (3rd-party)](https://vaporlens.app/app/3483740/cast_n_chill/stats/details).

## 2. The seven business questions

**1. Is there demonstrated demand?** Yes. Fishing + cozy + collection has multiple well-reviewed releases. At the top, Cast n Chill has 5,326 English reviews at $14.99. In the middle are Fishing Inc (1,980), Meow Squad (529) and Idle Waters (354) at $4.99–5.99. The floor is real too: Incremental Fishing has 52 reviews despite 96% positive and 22 languages. Demand exists, but most releases in the niche stay small.

**2. How crowded is the subgenre, and what gap can we own?** Very crowded: at least six fishing incrementals launched in roughly 12 months. Most lean **idle / clicker / desktop-companion**, and Fishing Inc already uses species-based progression. Few low-price titles offer **active, readable fishing in a handcrafted pond where *where you cast* matters**. The gap we can credibly own is **"read the pond"**: visible habitats (shade, moss, roots, reeds, lilies, stones, depth, ice holes) that change which fish appear, combined with a tactile rod/line fight. This is a hypothesis, to be validated in playtests (section 3).

**3. Table stakes vs. distinct proposition.**
- *Table stakes:* upgrades, collection log, several locations, rarities, achievements, Steam Cloud, a demo, a ≈$5 price, a relaxing tone.
- *Missing vs. competitors:* an idle/passive mode, localisation, a long content list.
- *Distinct:* habitat-cell forecast and discovery, a skill fight with a visible bending rod and tension line, and per-species rarity mastery shown openly (L20 = 50% Legendary). The mastery mechanic alone overlaps Fishing Inc, so it is a supporting feature, not the headline.

**4. Defensible price band.** Direct comps are $4.99–$5.99 (200–266 RUB). Cast n Chill earns $14.99 with far more content and polish. The current MVP has 2 ponds and 12 species; a full play-through is roughly 1–2 h to the Frostmere unlock (the simulation median is 32 min of efficient play) plus mastery grinding. **Recommendation: $4.99 (≈200 RUB regional default).** If playtests show under 3 h of satisfying play, fall back to $3.99 or add a third pond first. Do not price high to make the revenue target look easier.

**5. Audience and justified tags.**
- *Audience:* cozy/collection players who also enjoy light skill play, Steam Deck/controller players, and fans of Cast n Chill and Fishing Inc who want something between idle and simulation.
- *Justified tags:* Fishing, Pixel Graphics, Cozy, Relaxing, Collectathon, Incremental, Casual, 2D, Nature, Singleplayer, Controller, Atmospheric.
- *Not justified (do not use):* Idler, Desktop Companion, Co-op, Creature Collector.

**6. Why choose PONDLIGHT?** You read a living pond: every patch of water hints at different fish, your cast lands exactly where you aimed, and the fight is in your hands — the rod bends, the line tightens and reddens, and you let go when the fish surges. Each species has its own mastery, so even a Bluegill you've caught 50 times can become Legendary.

**7. Three biggest commercial risks and cheap tests.**
| Risk | Cheap test |
|---|---|
| The hook is not distinct enough. Players may want idle comfort or see "another fishing incremental". | Five-second capsule/GIF test with 10–20 target players, then playtest: do players mention *habitats* or *rod feel* unprompted? If not, rework the trailer/capsule before building content. |
| Too little content leads to refunds inside Steam's 2-hour window. GameDiscoverCo's median refund rate is 8% of copies for 1.0 launches [3rd-party]. | Measure playtest session length and "would you keep playing?" before choosing a price; track demo playtime in Steamworks. |
| Discovery: a small niche game gets no traffic. Plus for a Russia-based developer: payout and tax friction (section 4). | Steam Coming Soon page and demo in a non-Next-Fest period. Measure wishlist velocity per source before spending the single Next Fest entry. |

## 3. Steam platform facts verified (2026-11-02)

- **Steam Direct fee:** $100 per app, non-refundable. It is recouped in the payment after the app reaches $1,000 Adjusted Gross Revenue [Steam]. [Source](https://partner.steamgames.com/doc/gettingstarted/appfee)
- **Payouts:** Valve pays **in US dollars only**. US bank accounts get ACH; non-US accounts get **USD SWIFT** wires. Valve may hold payments until $100 is earned. Your bank must be able to accept USD [Steam]. [Source](https://partner.steamgames.com/doc/finance/payments_salesreporting/faq), [Workshop payment FAQ](https://steamcommunity.com/workshop/workshoppaymentinfofaq/)
- **Revenue share:** 30% until $10M, then 25% to $50M, then 20%, as announced in 2018 [3rd-party coverage]. We could not reach the current Steam Distribution Agreement text; verify during onboarding. [Coverage](https://techcrunch.com/?p=1753729)
- **Wishlists:** Valve's documentation says *"Wishlists can be an important factor in determining where your game appears on Steam"* and that the store is personalised from many factors. Wishlisters get e-mail/push notifications at launch and for qualifying discounts (≈2-week cooldown) [Steam]. **Correction to our brief:** the brief assumed Valve says wishlists are "mostly not a direct factor". The current Valve page does not say that, so we report what it actually says. Purchases and player activity still matter for visibility. [Source](https://partner.steamgames.com/doc/marketing/wishlist)
- **Next Fest:** *"titles may only participate in ONE Next Fest"*. Requirements:
  - A public base-game store page.
  - A playable demo when the Fest begins. Submit the demo 5 weeks before if it releases before Press Preview, otherwise 3 weeks before.
  - The game must not release before the edition ends.
  
  Upcoming editions listed: February 2027 and June 2027. Exact dates and deadlines must be checked on Steamworks [Steam]. [Source](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)
- **Wishlist → sales benchmarks [3rd-party]:**
  - GameDiscoverCo: median first-week sales ≈ **0.15× launch wishlists** for 2024–2025 games with ≥25k wishlists, and ≈0.10× for games priced above $10.
  - The search summary of Simon Carless's Sep 2024–Sep 2025 study reports a median **10.5%** first-week conversion. This matches the brief's "≈10–11 per 100 wishlists".
  - Chris Zukowski: 2023–2025 games sold **0.22 copies per launch wishlist in month 1** and **0.70 in year 1** (down from 0.45 / 0.99 for 2020–2022 games).
  
  The ratio is *total first-week paid units ÷ launch wishlists*, not a guaranteed purchase by each wishlister, and it varies enormously by game. [Inven Global on Zukowski & GameDiscoverCo, 2026-10-15](https://www.invenglobal.com/articles/27273/steam-wishlist-inflation-value-of-1-wishlist-cut-in-half-but-predictive-power-remains-unchanged), [Carless 2020 survey](https://www.gamedeveloper.com/business/steam-the-new-wishlists-to-first-week-sales-expectations)
- **Refunds [3rd-party]:** GameDiscoverCo median refund rate is 8% of copies for 1.0 launches and 12.4% for Early Access. [Source](https://gamedevreports.substack.com/p/gamediscoverco-steam-refunds-research)

## 4. Russia-specific facts that affect the ₽ target

- Russian VAT rose to **22% from 2026-01-01** (Federal Law 425-FZ). Valve has historically absorbed RU VAT inside developer-set prices, so it reduces net revenue per RU sale [3rd-party]. [ФНС](https://www.nalog.gov.ru/rn26/news/smi/16596761/), [wnhub on Valve & the "Google tax"](https://wnhub.io/news/stores-and-publishing/item-12038)
- **Since 2024-08-16 Valve withholds an extra 30% on US sales for developers who are Russian tax residents**, after the partial suspension of the US–Russia tax treaty. This is reported from a Valve e-mail via DTF/WN Hub [3rd-party]. [Source](https://wnhub.io/news/stores-and-publishing/item-44710)
- Valve pays in USD via SWIFT only. Many Russian banks cannot receive USD SWIFT under current sanctions. Payment eligibility of the planned legal entity and bank is an **open pre-launch checklist item**, not something we can assume (see BUSINESS_MODEL.md §5).
- Russian buyers fund Steam wallets largely through third-party top-ups; for example, Sber's top-up carries a 6% fee [3rd-party, 2023]. This lowers effective RU demand at a given price. [Source](https://habr.com/ru/amp/publications/771724)

## 5. What we could not verify
- Current USD/RUB rate for planning (BUSINESS_MODEL uses a labelled assumption).
- The exact current revenue-share text of the Steam Distribution Agreement.
- Exact Next Fest 2027 dates and deadlines.
- Unit sales of any competitor.
- Whether Valve currently remits RU VAT out of the developer share or on top. We model a blended tax deduction instead.
