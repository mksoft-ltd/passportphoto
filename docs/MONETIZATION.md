# Passport Photo Studio — monetisation

Stage 5a (growth-monetization), 2026-08-05. Canonical for release-manager and
store-publisher. The strategy, competitive pricing analysis and growth plan are
in `docs/ASO.md`; this file is only the settled facts and the gate list.

## Model

**Free tier plus a single one-time non-consumable unlock.** No subscription, no
ads, no consumables, no wrapper SDK — native `in_app_purchase` per house style.
This is the right model here because there is no ongoing cost, no ongoing
content and no ongoing use: most people need this app once every ten years, and
a subscription for a decade-cycle utility is the kind of dark pattern the brand
is positioned against.

Competitive context: every one of the 25 top UK results for "passport photo" is
free-with-IAP, the category leader charges **£19.99** for its unlock, and the
per-photo web services charge **$6.95–$16.95 per set**. A high-street booth is
£8–15 per visit. £4.99 once for unlimited photos in every country is the
cheapest credible offer in the category.

## Product

| Field | Value |
|---|---|
| Product ID | `com.froggyeye.passportphoto.pro` |
| Type | Non-consumable, restorable |
| Display name | Passport Photo Studio Pro |
| Price | **£4.99** one-time (App Store £4.99 / $4.99 price point; Play base £4.99 with auto-conversion and PPP pricing on) |
| Store fee | 15% both stores — Apple Small Business Program (confirm enrolment) and Play's automatic 15% on the first $1M. Net ≈ £4.24 per unlock in the UK |
| Restore | "Restore purchase" reachable from the Home app bar on every launch |

The paywall shows the price only as reported by `ProductDetails.price`. **No
currency string is ever hardcoded, and no invented figure may appear in a
screenshot** — if the store does not answer, the button correctly falls back to
a bare "Unlock Pro".

## The gate

The gate lives in exactly one place: `ExportService`, which reads the
entitlement itself rather than trusting its caller
(`lib/features/export/export_service.dart`).

### Free — a working product, not a demo

- All **30 document specs across 21 countries**, plus ICAO Doc 9303 and
  Schengen generic fallbacks. **Countries are never gated**, ever. This is
  load-bearing for the listing's credibility (screenshot 04) and is not
  available as an ARPU lever.
- Camera capture with the live face-guide overlay, and gallery import.
- Automatic crop and scale to the spec's exact millimetre and DPI figures.
- The **complete seven-check compliance report**, including failures and their
  plain-English reasons. The report is what the free tier is really selling.
- The 4×6" print-sheet preview, watermarked.
- A watermarked save to the gallery, downscaled to a 600 px long edge.

### Pro — £4.99

- The full-resolution unwatermarked JPEG at the spec's exact pixel dimensions.
- The 4×6" print sheet, unwatermarked, tiled at 300 dpi with cutting gaps.
- Gallery saves without the watermark.

## One change owed before submission

**SEC-4 — cap the locked `/result` preview at a 640 px long edge.** Today the
free tier is shown the full-resolution unwatermarked crop on screen (~1035 ×
1332 device pixels against 827 × 1063 of required output), which is more than
the paid file needs. The security audit judged the screenshot workaround weak
because printing needs the exact file; that holds for the print path but not for
the **digital upload** path, which is now the majority route for UK passport
renewals and is available for US applications too. An uploading user faces no
dimensional check — only a minimum size — so a cropped screenshot of the free
preview clears it, while the paywall offers that same user a *smaller* 600 px
watermarked file. Capping the locked preview at 640 px puts it below both the
UK's 600 × 750 and the US's 600 × 600 digital minimums, keeps the crop clearly
readable, and makes `export_service.dart`'s "a screenshot is not a usable
substitute" comment true of the app as built. Full reasoning in `docs/ASO.md`
§7.1.

## Not doing

- **Ads.** The listing claims "No ads", the privacy label carries no advertising
  identifier, and reversing that would mean re-declaring both stores' labels for
  revenue that is not worth it on a £4.99 app.
- **Gating any country.** See above.
- **A subscription.** Revisit only if a B2B tier for travel agencies and
  post-office counters ever materialises (`docs/ASO.md` §12), and even then a
  separate SKU is likelier to be right.
- **Introductory or launch discounting.** A non-consumable cannot carry an
  introductory price, and discounting the cheapest credible offer in the
  category signals the normal price is negotiable.
