# PONDLIGHT — Business model & the 1,000,000 ₽ target

This is a **planning model, not a forecast or a promise**. Every input is labelled. Verified facts are in STEAM_MARKET_RESEARCH.md (observed 2026-11-02).

## 1. Formulas

```
ASP_usd   = list_price × regional_mix_factor × (1 − average_discount)       # what a kept copy really pays, incl. VAT
ASP_rub   = ASP_usd × FX
A) Gross consumer spend target:   kept_copies = 1,000,000 ₽ / ASP_rub
                                   sold_copies = kept_copies / (1 − refund_rate)
B) Developer receipts target (before the developer's own income tax):
   per_copy = ASP_rub × (1 − tax_in_price) × (1 − steam_share) × (1 − 0.30 × US_share if RU tax resident) × (1 − fx_and_bank_cost)
   kept_copies = 1,000,000 ₽ / per_copy ;  sold_copies = kept_copies / (1 − refund_rate)
Wishlists needed ≈ sold_copies / year1_sales_per_launch_wishlist
```
Fixed costs: the $100 Steam Direct fee is recouped after $1,000 AGR [Steam]. Bank/SWIFT fees per payout are folded into `fx_and_bank_cost` [Assumption].

## 2. Inputs per case

| Input | Conservative | Base | Strong | Label |
|---|---|---|---|---|
| List price (USD) | 4.99 | 4.99 | 5.99 | Assumption, inside the observed $4.99–5.99 comp band |
| Regional mix factor (blended price vs US) | 0.65 | 0.75 | 0.80 | Assumption (RU default ≈ 200 ₽ ≈ 0.47× US at FX 85; CIS/LATAM/Asia lower, EU ≈ US) |
| Average discount over the first year (launch −10–15%, seasonal −20–40%) | 25% | 20% | 15% | Assumption |
| VAT/sales tax inside the price (blended) | 15% | 12% | 10% | Assumption (EU ~20%, RU 22% since 2026, US tax on top of price) |
| Refunds (share of copies) | 12% | 9% | 8% | 3rd-party: GameDiscoverCo median 8% (1.0) / 12.4% (EA) |
| Steam share | 30% | 30% | 30% | Steam (tiers only above $10M) |
| US share of revenue | 30% | 25% | 25% | Assumption |
| Extra 30% US withholding (RU tax resident) | yes | yes | **no** (non-RU entity) | 3rd-party report of Valve e-mail, Aug 2024 |
| FX + bank/SWIFT/conversion cost | 3% | 2% | 1.5% | Assumption |
| FX USD/RUB | 85 | 85 | 85 | **Assumption — not verified; re-run with the rate on the planning date** |
| Year-1 sales per launch wishlist | 0.70 | 0.70 | 0.70 | 3rd-party: Zukowski, 2023–2025 cohort |

## 3. Results

| | Conservative | Base | Strong |
|---|---|---|---|
| Realised price per kept copy | $2.43 ≈ 207 ₽ | $2.99 ≈ 254 ₽ | $4.07 ≈ 346 ₽ |
| **A) 1,000,000 ₽ gross spend: kept copies** | **≈ 4,840** | **≈ 3,930** | **≈ 2,890** |
| A) copies sold incl. later refunds | ≈ 5,500 | ≈ 4,320 | ≈ 3,140 |
| Developer receipt per kept copy | ≈ 109 ₽ (52% of spend) | ≈ 142 ₽ (56%) | ≈ 215 ₽ (62%) |
| **B) 1,000,000 ₽ to the developer: kept copies** | **≈ 9,210** | **≈ 7,040** | **≈ 4,650** |
| B) copies sold incl. refunds | ≈ 10,460 | ≈ 7,730 | ≈ 5,060 |
| Launch wishlists implied for B within ~1 year | ≈ 15,000 | ≈ 11,000 | ≈ 7,200 |
| Implied first-week units (0.10–0.15 × wishlists) | ≈ 1,500–2,240 | ≈ 1,100–1,660 | ≈ 720–1,080 |

**Reading it honestly:**
* Reaching 1M ₽ **to the developer** needs ~5k–10k kept copies and roughly 7k–15k launch wishlists, depending mostly on price realisation and on the developer's tax residency. The extra 30% US withholding plus RU VAT alone cost ~7–9% of every sale.
* In this niche, comparable $5 games range from ~50 reviews (Incremental Fishing) to ~2,000 (Fishing Inc). We have no public unit sales, so we cannot say which side PONDLIGHT lands on. The target is **plausible only if validation signals are strong** (STEAM_MARKETING_PLAN.md gates). It is **not** the expected outcome of an average release.
* A modest goal of 1M ₽ *gross spend* (~3–5k kept copies) is meaningfully easier than 1M ₽ *developer receipts*. Keep the two numbers separate in every report.

## 4. Unknown until there is sales data
Real regional mix, discount depth that works for this game, refund rate (driven by play length vs the 2-hour window), wishlist conversion, US share, the actual VAT treatment per region, and the FX on payout days.
Update this table monthly from Steamworks sales reports. Treat every number above as a placeholder until then.

## 5. Pre-launch payment & tax checklist (must be resolved by the owner, cannot be faked)
- [ ] Decide the legal entity and **tax residency**. This changes the US withholding (30% extra for RU residents per the Aug 2024 report) and the treaty forms (W-8BEN / W-8BEN-E) in Steamworks tax onboarding.
- [ ] Confirm in writing that the receiving bank can accept **USD SWIFT wires from Valve**. Valve pays USD only [Steam]; many RU banks cannot receive USD SWIFT. Do not use another person's account or details.
- [ ] Complete Steamworks onboarding: identity, bank, tax interview, $100 Steam Direct fee.
- [ ] Plan for the minimum payout ($100 hold) and the monthly payment cadence in cash-flow.
- [ ] Get local accountant advice on currency control and income-tax treatment of foreign USD receipts (outside this model; this model stops *before* the developer's own income tax).
