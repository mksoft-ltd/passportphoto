# Passport Photo Studio — ASO, pricing and growth

Stage 5a (growth-monetization), 2026-08-05. Written for release-manager: the
**Verbatim block** in §9 is what goes into `ios/fastlane/metadata/` and
`android/fastlane/metadata/android/` unchanged. Everything else is the reasoning
behind it.

Sources for the competitive numbers in this document: the iTunes Search API
(`itunes.apple.com/search?term=passport+photo&country=gb`, pulled 2026-08-05)
and public listing pages. No paid ASO tool was used, so **there are no search-
volume figures here** — where a keyword is ranked as high or low value, the
reasoning is stated so the next person can disagree with it on the merits
rather than on an invented number.

---

## 1. What we are actually competing against

Twenty-five UK results for "passport photo", every single one **free with an
in-app purchase**. Not one paid-upfront app in the set. The top of the market:

| App | Store rating count | Category | Money |
|---|---|---|---|
| Passport Photo UK. (TAPUNIVERSE) | 12,886 · 4.74 | Graphics & Design | IAP **£19.99** |
| Passport Photo – PhotoAiD | 11,500 · 4.46 | Photo & Video | per-photo, $6.95–$16.95 across its brands |
| Passport Photo – ID Photo (V. Schaefer) | 4,506 · 4.45 (GB) / 20,843 (US) | Photo & Video | IAP |
| Passport Photo – Smartphone iD | 1,170 · 4.68 | Photo & Video | per-photo |
| ID Photo–Passport Photo maker (SenseTime) | 1,869 (GB) / 25,385 (US) | Productivity | IAP |

Three things follow, and they drive every recommendation below.

**We are not going to win on breadth.** Rivals advertise "150+ countries and
500+ document types". We have 30 specs across 21 countries plus ICAO and
Schengen fallbacks. That is a good product and a bad billboard — so the
country count must never be the hook. It moves out of the screenshot headline
(§5) and into body copy where it can be framed alongside the fallbacks.

**We are going to win on price and on honesty.** £4.99 once, unlimited photos,
against a £19.99 unlock and against services that charge $7–17 *per photo set*
and a booth that charges £8–15 *per visit*. That gap is the single strongest
message we have and it belongs in the subtitle, the short description and the
first line of the long description.

**The category's marketing is full of claims we have banned ourselves from
making** — "99.7% Government Acceptance Guarantee", "100% accepted for all UK
official documents", "government-approved". `BRAND.md` forbids all of it, which
costs us the easiest hook in the category and buys us the only defensible one:
we are the app that tells you *before* you print, and shows its working. One
rival's AI retouching reportedly fell foul of a January 2026 US State
Department rule change; this app does not retouch, beautify or replace
backgrounds at all, which is worth a description line on its own terms.

**Our real launch handicap is reviews, not keywords.** Competitors carry
4,500–25,000 ratings. A zero-rating app will not out-rank them on the head term
in year one no matter how good the keyword field is. Plan accordingly: §7 makes
the review prompt the highest-priority post-1.0 feature, and the keyword
strategy below buys traffic on long tails where a 0-review app can actually
place.

---

## 2. Keyword research

### How the two stores differ, and what that means here

iOS indexes the **app name, the subtitle and the 100-character keyword field**,
and it *combines* words across those fields into phrases automatically. So a
word already in the title or subtitle must never be repeated in the keyword
field — every repeat is a wasted character. iOS does **not** index the
description at all.

Play indexes the **title, the short description and the long description**, with
the title weighted hardest and repetition in the long description subject to
diminishing returns and to Play's spam policy. So the same research produces two
different artefacts: a tight comma-separated list for iOS, and natural sentences
containing target phrases for Play.

### Head terms, ranked by value to this app

| Term | Why it matters | Realistic prospect |
|---|---|---|
| **passport photo** | The category term; almost all intent flows through it | Cannot win it at launch. Must still be in the title — it is the relevance anchor everything else combines against |
| **id photo** | Second-largest, and the one rivals put in their titles | Winnable on the long tails; get "id" into the subtitle |
| **passport photo booth** / **photo booth** | Highest-intent term we have: someone typing "booth" is deciding whether to leave the house. Our shot 02 answers exactly that | Good target — "booth" goes in the keyword field, not the title, because the app is the *alternative* to a booth and the title should not read as one |
| **visa photo** | Distinct audience (frequent applicants) with a much stronger repeat-need, and lower competition than "passport photo" | Target hard. "visa" earns its place in the subtitle |
| **passport photo maker** / **passport size photo** | Rival titles are saturated with "maker"; "size" is how non-native English speakers phrase it, and a large slice of the visa audience is exactly that | "maker" and "size" both go in the keyword field |
| **biometric photo** | European phrasing (DE/FR/NL all say *biometrisch/biométrique*) and it is what the spec actually is | Keyword field; also the bridge term for the later localisations in §7 |

### Long tails worth owning

These are where a new app can actually place, because they are specific enough
that the giants' generic listings do not target them:

- **Dimension tails:** `35x45`, `2x2`, `passport photo 35x45mm`, `2x2 inch
  photo`. High intent — someone quoting a millimetre figure has already read the
  government page and is looking for a tool, not an explainer. `35x45` covers
  17 of our 30 specs; `2x2` covers the US and Indian ones.
- **Document tails:** `driving licence photo` (UK spelling) / `driver's license
  photo` (US), `id card photo`, `green card photo`, `residence permit photo`.
- **Country tails:** `uk passport photo`, `us passport photo`, `schengen visa
  photo`, `india passport photo`, `china visa photo`, `japan passport photo`,
  `uae visa photo`. These belong in the Play long description and on
  froggyeye.com, **not** in the iOS keyword field — 21 country names will not
  fit in 100 characters and picking three of them wastes the field.
- **Situation tails:** `baby passport photo`, `child passport photo`,
  `passport photo at home`, `print passport photo`, `passport renewal photo`.
  "baby"/"child" is a genuinely under-served intent — a booth is impractical
  with an infant and it is one of our named target users.

### Terms deliberately excluded

- **Any competitor brand name.** Apple removes them and it invites a dispute we
  would lose.
- **"official", "approved", "guaranteed", "accepted", "government", "HMPO",
  "USCIS", "DVLA", "ICAO" in the indexed fields.** The first four are banned by
  `BRAND.md`'s tone rules; the agency names imply an endorsement that does not
  exist and are exactly what App Review reads as a 2.3.1 metadata problem.
  ICAO appears once in the long description as a *sizing standard we follow*
  ("sized to the ICAO Doc 9303 layout"), which is a factual reference, and
  nowhere in a keyword field.
- **"AI", "instant", "professional", "studio quality".** Banned by tone, and in
  this app's case actively misleading — there is no model doing anything
  generative, and saying so is a differentiator.
- **"free".** Apple treats it as noise and Play reads it as promotional text in
  a title. The *substance* of free (every country unlocked) is sold in the
  screenshots instead.

### iOS keyword field — final drafts

Two localisations, because Apple gives a separate 100-character field to each,
and en-GB and en-US serve almost disjoint spelling and dimension vocabularies.
Setting up both is the cheapest ASO win available at launch.

**en-GB** (serves UK, IE, AU, NZ, ZA, IN, SG) — 95 characters:

```
booth,biometric,size,maker,crop,print,35x45,licence,child,baby,renewal,schengen,sheet,resize,uk
```

**en-US** (serves US, CA and the default storefronts) — 95 characters:

```
booth,biometric,size,maker,crop,print,2x2,license,green,card,child,baby,renewal,sheet,resize,us
```

No spaces after commas (each would cost a character). No plurals — `photo`
already sits in the title. Nothing here repeats `passport`, `photo`, `studio`,
`id`, `visa`, `one` or `payment`, all of which the title and subtitle already
supply for phrase-building.

### Play long description — keyword targets

Each of these should appear at least once, in a sentence that reads naturally
to a human. Do not stack them into a list; Play's spam policy notices, and the
2026 Play listing quality guidance downranks keyword blocks.

`passport photo app` · `passport photo maker` · `passport size photo` ·
`id photo` · `visa photo` · `biometric photo` · `photo booth` ·
`print passport photos at home` · `35x45mm` · `2x2 inch` ·
`driving licence photo` · `baby passport photo` · `passport renewal` ·
`uk passport photo` · `us passport photo` · `schengen visa photo` ·
`india passport photo` · `china visa photo`

---

## 3. Title, subtitle and short description

### Apple App Store

| Field | Limit | Recommended | Length |
|---|---|---|---|
| Name | 30 | `Passport Photo Studio` | 21 |
| Subtitle | 30 | `ID & visa photos. One payment.` | 30 |

The name stays exactly as registered — it matches the Play record, the bundle
ID and the support page, and a passport app whose own name looks keyword-stuffed
undermines the one thing it is selling. The nine spare characters are worth less
than that consistency.

The subtitle does three jobs at once and uses all 30 characters: it supplies
`id` and `visa` for phrase-building with `photo` from the title (giving Apple
"id photo", "visa photo", "passport photo", "id photo studio"), and its second
sentence is the competitive wedge against a £19.99 unlock and per-photo pricing.

Held in reserve, **not** for launch: `Passport Photo Studio: ID Visa` (exactly
30) as a title, which would move `id` and `visa` into the highest-weighted
field. Only worth doing if §8's experiment 1 shows the head terms are not
converting — it reads like a keyword field, which costs trust in this category.

### Google Play

| Field | Limit | Recommended | Length |
|---|---|---|---|
| Title | 30 | `Passport Photo Studio` | 21 |
| Short description | 80 | `Skip the booth. Passport, visa and ID photos checked against the spec.` | 70 |

Play weights the title harder than Apple does and has no subtitle, so the short
description carries the keyword load. This draft holds `passport photo`,
`visa`, `id photos`, `booth` and `spec` in one readable sentence, opens with the
benefit, and makes no acceptance claim.

If the name is taken on either store, the agreed fallbacks are **"Passport & ID
Photo Studio"** then **"ID & Passport Photo Studio"**. Note that the first
fallback is *better* for ASO than the primary name — it puts `id photo` in the
title for free — so if there is any doubt at record-creation time, take it
willingly rather than as a defeat.

---

## 4. Categories

**Apple — primary `Photo & Video`, secondary `Utilities`.**

Photo & Video is where the category's search traffic and its top apps live
(PhotoAiD, Schaefer, Smartphone iD all sit there), and the primary category is a
relevance signal that compounds with the keyword field. Utilities as secondary
is honest — the app is a measuring tool that happens to handle images — and it
is the category where Apple's editorial team features privacy-first
single-purpose utilities, which is the realistic featuring path (§6).

Noted and rejected: the UK category leader (Passport Photo UK, 12.9k ratings)
sits in **Graphics & Design**, almost certainly because it is a thin category
where a top-chart placement is cheap. That is a rational play for an app with
enough installs to chart. We will not chart in any category at launch, so
buying a chart position we cannot reach in exchange for a weaker relevance
signal on the terms we *can* rank for is the wrong trade. Revisit only if the
app ever approaches chart range.

**Google Play — `Photography`.** Play has one category, and Photography is where
the equivalent listings sit. Tools is the alternative and is worse: Play's
Photography browse surfaces are more actively merchandised, and the Data safety
scrutiny is identical either way. Pick up to five Play tags from Play's fixed
list, favouring the photo-editing and document-adjacent ones; tags feed Play's
similar-app clustering, which is a free acquisition channel for a listing with
no reviews yet.

**Content rating:** the app has no user-generated content, no ads, no social
features and no external links beyond the privacy policy — 4+ / PEGI 3 /
Everyone. Nothing here should trigger a questionnaire branch.

---

## 5. Screenshot set — review, reorder and rewrite

`store_assets/screenshot_specs.md` has been updated in place with everything in
this section; this is the reasoning, that file is the spec.

### Order

Changed from **result → sheet → picker → home → paywall** to
**result → sheet → home → picker → paywall**.

The first three shots are what appears in App Store search results, so they must
carry outcome, money and differentiator. Privacy ("your photo never leaves your
phone") is a stronger third than a country count we lose on — see §1. The picker
still earns its place at four as the proof that nothing is gated, which is what
makes the free tier credible; it just should not be one of the three shots a
stranger sees while scrolling past.

### Copy changes, and why each one

**Shot 01 headline — "Passport photos approved first time" is withdrawn.** This
is not a style preference. `BRAND.md` bans promising acceptance and lists
"approved by" among the words we do not use; the headline promises approval in
four words on the highest-visibility surface in the listing, while the app's own
`SOURCES.md` is candid that some eye-line figures are derived rather than
published. It is also the exact claim shape ("99.7% acceptance guarantee") that
makes the rest of this category untrustworthy, and a metadata claim App Review
can reasonably ask us to substantiate. Replaced with **"Seven checks before you
print"** — same outcome-first structure, states the differentiator (nobody else
shows their working), and it is true.

**Shot 01 subheadline** now names the checks instead of counting them:
"Pass or fail on face size, eye line and background." Concrete beats numeric, it
leads with the outcome, and it wraps to two balanced lines in the renderer —
the first draft put an em-dash at the head of line two, which is why this one
reads the way it does.

**"Six checks" → "seven" everywhere in the file** (§1's seeded-state table and
shot 01's copy and state description, including the `6 / 6 passed` capture
note → `7 / 7`). This is code-review finding RR-3; the seventh check ("Eye line
within spec") landed in the 4c fix round.

**Shot 02 subheadline drops the currency figure.** "a booth charges £10–15" is a
UK number sitting in a screenshot that also serves the US, EU, IN and AU
storefronts from a single English set, and it is the only price claim in the
set that we would have to defend. "Booths charge far more" is the audit's own
suggested fallback, is true in every market we ship to, and costs the headline
nothing.

**Shot 03 (was 04) subheadline — SEC-11.** "No ads. No tracking. No account.
Everything runs offline." is replaced by **"No ads. No account. Your photo is
never uploaded."** Each clause verified against the built app rather than
against the old label: no ad SDK in `pubspec.yaml` (confirmed — no
`google_mobile_ads`, nothing ad-adjacent), no account or backend anywhere in the
codebase, and the photo genuinely never leaves the device (model bundled,
verified in the release AAB by the stage-4b audit). The two clauses that are now
false — "no tracking" and "everything runs offline" — are gone, because the
bundled ML Kit SDK reports a device identifier and diagnostics to Google and
that is exactly what the corrected Data safety form declares. A screenshot
asserting "everything runs offline" next to a Data safety form declaring Device
ID collection is a contradiction on the record; the headline "Your photo never
leaves your phone" is precise, checkable and survives untouched. The shot's
"why it earns a shot" rationale has been rewritten to rest on on-device
processing rather than on the withdrawn "No data collected" label.

**Shot 04 (was 03) stops leading with the country count.** "21 countries, 30
documents" invites a comparison with "150+ countries" that we lose. The shot's
real content is that *nothing is locked* — no lock badges anywhere in the
picker — which is a claim no rival in the set can make. Headline becomes
**"Every country, free"** with the subheadline "Passport, visa and ID specs —
nothing behind the paywall." The actual counts move to the long description,
where they can sit next to the ICAO and Schengen fallbacks that cover the rest
of the world.

**Shot 05 is unchanged.** "One payment. No subscription." is the strongest
sentence in the set against a £19.99 unlock and per-photo services, and it
doubles as Apple's mandatory IAP review screenshot. The existing rule stands and
is worth restating for stage 7: a real store price or no price at all — never a
placeholder.

### One phrase worth watching

Shot 01's old subheadline said "against the official spec", and `BRAND.md`
sanctions that exact phrasing. The new copy says "against the country's own
spec" instead. It is the same claim without the adjective that shades toward
endorsement, and it sits better beside `SOURCES.md`'s admission that 16
authorities publish no eye-line figure at all. `BRAND.md` is not wrong, and this
is not a request to change it — but where the two differ, the screenshot uses
the narrower phrasing.

---

## 6. Growth strategy

### 6.1 ASO is the channel

For a portfolio with no ad budget, no analytics and no tracking, store search is
not the main channel — it is effectively the only one. Everything else in this
section exists to feed the two inputs that store search actually responds to:
**conversion rate** and **ratings**.

Launch checklist, in order of leverage:

1. **Both English localisations configured** (en-GB and en-US) with the separate
   keyword fields in §2. Free, doubles the indexed surface, and takes ten
   minutes in App Store Connect.
2. **Screenshots as specced in §5.** Listing conversion moves ranking more than
   any keyword edit; the first two shots are worth more than the whole keyword
   field.
3. **Long description written for humans first**, with §2's Play targets woven
   in. Play's own 2026 listing guidance penalises keyword blocks.
4. **Iterate the keyword field at 30 and 90 days.** The launch field is a
   hypothesis. Apple's own "Search terms" report in App Analytics is available
   without any SDK — it is store-side, needs no tracking code in the app, and is
   the only honest measurement channel this app has.

### 6.2 Where this audience already is

Named concretely, because "post on Reddit" is not a plan:

- **r/passports** — extremely active, and a large share of its threads are
  people posting a photo asking whether it will be rejected. This is the single
  best-matched community in existence for this app.
- **r/ukvisa**, **r/USCIS**, **r/immigration**, **r/IWantOut**, **r/expats**,
  **r/AmerExit** — visa applicants, the repeat-need segment.
- **r/Schengen** and country-specific expat subs (r/germany, r/Netherlands,
  r/japanlife) whenever a spec for that country ships.
- **Forums that outrank Reddit for these queries:** ImmigrationBoards (UK),
  VisaJourney and Trackitt (US), Expat Forum. Older, slower, and their threads
  rank on Google for years.
- **Facebook expat groups** ("Brits in Spain", "Expats in Dubai") — high volume,
  hostile to link-drops, receptive to a person answering a question.

**How to use them, which is the part that matters.** Do not post app links.
Every one of these communities punishes it, and a removed post costs more than
it earns. The play is the **free spec reference on froggyeye.com** (§6.3):
answer the question in the thread, in full, and link the reference page only
when it adds something the answer did not. The app is discovered from the
reference page, not from the forum post.

### 6.3 froggyeye.com — the highest-leverage non-store asset

The app's page on froggyeye.com is required by house convention anyway (support
and marketing URL). Make it more than a landing page: **one page per document
spec**, generated from `assets/specs/photo_specs.json`, which is already
structured data with per-spec provenance in `SOURCES.md`.

That is 30 pages targeting exactly the queries this audience types into Google —
"UK passport photo size", "US passport photo 2x2 requirements", "Schengen visa
photo dimensions" — each one citing the authority it came from. It costs one
generator script, it is the sort of page forums and Reddit answers link to
voluntarily, and it feeds the app store listing from the top of the funnel. It
also has a second life as a defence: when a reviewer or a user asks where a
number came from, the page already says.

Content topics that fit this app specifically, ranked:

1. **"Why passport photos get rejected"** — the highest-intent search in the
   niche, and the article our compliance report is the answer to.
2. **"How to take a passport photo of a baby or toddler"** — under-served,
   emotionally charged, and a named target user.
3. **"UK passport photo: the digital upload rules vs the printed rules"** — a
   genuine source of confusion, and it explains why the app produces both a file
   and a print sheet.
4. **"Passport photo sizes by country"** — the hub page all 30 spec pages link
   from.
5. **"What 'biometric photo' actually means"** — the bridge term for the EU
   markets, and the natural place to explain eye lines and face-height bands.

### 6.4 Social and featuring

Social channels ranked by fit — and honestly, none of them is where this app
grows, because the need is episodic rather than interest-based. In order:
**YouTube Shorts / TikTok** (a 20-second "take a passport photo of a wriggling
toddler" clip is genuinely watchable and the product demo *is* the content),
then **Pinterest** (the spec pages have a natural infographic form and Pinterest
ranks them for years), then Instagram, then nothing.

**Featuring** is worth engineering for, because it is free and this app has an
unusually good pitch for it. Apple's editorial teams feature privacy-first
single-purpose utilities, and this app's story is exactly that shape: a
government-form task done entirely on the device, with a tool that tells you
when it failed rather than claiming it never does. What makes it featurable, in
priority order: a genuinely well-crafted icon and screenshot set (done),
accessibility that actually holds up (the `BRAND.md` accessibility section is
already stronger than most of this category), and a clean privacy story told
*precisely* — which the corrected label now lets us do without overclaiming.
Submit a featuring nomination through App Store Connect at launch; it costs one
form.

### 6.5 Retention — and why chasing it here is a mistake

Be honest about the shape of this product: most users need it **once every ten
years**. Day-30 retention will be terrible and that is not a defect. Building
streaks, daily notifications or a content-refresh loop into a passport photo app
would be a dark pattern in a product whose entire brand is the absence of them,
and the app currently ships **no notification dependency at all** — which is
correct and should stay that way.

What to optimise instead:

- **First-session conversion.** The single visit is the whole business. This is
  why §7's SEC-4 call matters more here than the same call would in a
  subscription app.
- **The second head in the household.** Families renew together. "Do the whole
  family" is a real and honest expansion of a single session, and it is already
  supported — nothing about the app limits you to one photo.
- **Word of mouth at the counter.** The 4×6" print sheet is physically handed to
  a shop assistant who sees a stranger's phone-made photo work. Putting a
  discreet "Passport Photo Studio" line in the sheet's cutting margin (not on
  the photos) would carry the name into that moment. Low effort, MEDIUM
  opportunity, and it is the only viral surface this product has.
- **Ratings, at the right moment** — see §7.

---

## 7. Required product features, prioritised

| # | Feature | Complexity | Revenue impact | Priority |
|---|---|---|---|---|
| 1 | **In-app review prompt** after a successful export | Low (`in_app_review`, native StoreKit / Play API, no tracking, ~20 lines) | Indirect but the largest single lever — ratings are the launch handicap (§1) | **HIGH** |
| 2 | **SEC-4: cap the locked preview's resolution** | Low (one `_downscale` call on the locked path) | Directly protects the £4.99 for the digital-upload majority — see §7.1 | **HIGH** |
| 3 | **Studio name in the print sheet's cutting margin** | Low | Word of mouth at the photo counter | MEDIUM |
| 4 | **froggyeye.com spec-page generator** from `photo_specs.json` | Low (script, not app code) | The whole top of the funnel (§6.3) | **HIGH** (site, not app) |
| 5 | **More country specs**, driven by which storefronts convert | Medium (data + provenance per spec, the expensive part is `SOURCES.md` discipline) | Widens the addressable market; also closes the breadth gap in §1 | MEDIUM |
| 6 | **Localised store metadata** (DE/FR/ES/IT/NL/JP) without translating the app | Low | Each is a separate indexed keyword field in a market where we already ship a spec | MEDIUM |
| 7 | **Background replacement** | High | Would let us compete on the one feature every rival advertises — but it edits the photo, which is the thing we currently say we never do | EXPERIMENTAL |
| 8 | **Direct print / AirPrint handoff** | Medium | Removes the last step between the export and the artefact | MEDIUM |

Items 1 and 2 both touch shipping code after the stage-4 gates closed. Item 1
adds a dependency and would reopen the security and privacy-label review, so it
belongs in **1.1**, not in the submission build — the review prompt cannot fire
before there are users anyway. Item 2 is a change on an existing code path with
no new dependency and should go into **1.0**; it is the one recommendation here
that release-manager and the fix round need to act on before submission.

### 7.1 SEC-4 — my call: cap the locked preview

**Cap it.** The security audit's framing assumed the screenshot workaround is
weak because a printed photo needs the exact file, and for the print path that
is right — the print sheet is already watermarked, and a hand-cropped screenshot
is not dimensionally exact, so the person who tries it is the person most likely
to get rejected. But that reasoning does not survive contact with our primary
market: UK passport renewals are overwhelmingly **digital uploads** now, and the
US online application accepts an uploaded JPEG too. For an uploading user there
is no printing step and no dimensional check on their side — the minimum is
simply a large enough image at the right aspect, and a cropped screenshot of our
`/result` preview clears it comfortably (the audit measured ~1035 × 1332 device
pixels on screen against 827 × 1063 of required output). So the free tier
currently hands the majority use case the entire paid artefact, one screenshot
away, while the paywall offers them a *smaller* 600 px watermarked file — a
state that is not just leaky but visibly illogical to the user. Cap the locked
preview's long edge at **640 px**, which sits below both the UK's 600 × 750 and
the US's 600 × 600 digital minimums while keeping the crop clearly readable, and
keep the full-resolution bytes on the paid path; label it "Preview — Pro exports
at full print resolution" so the softness reads as the upgrade being visible
rather than as the app looking cheap. The compliance report, not the preview
sharpness, is what the free tier is really selling, and it is unaffected. This
also resolves the internal inconsistency the auditor flagged: after this change,
`export_service.dart`'s "a screenshot is not a usable substitute" comment
becomes the policy the app actually implements.

### 7.2 Two in-app copy findings, one fixed here

**Fixed:** the paywall's own body text read *"A photo booth charges around £6
for one set."* That is one hardcoded English string shipped to every storefront,
so a US or eurozone buyer was being quoted pounds, and it is a price claim about
someone else's business — the same problem I dropped from screenshot 02, sitting
inside the app where I did not expect to find it. Changed to "A photo booth
charges several times more for a single set"
(`lib/features/purchase/paywall_screen.dart:100`). `flutter analyze` clean,
`flutter test` 285 passed / 0 skipped after the change. No test asserted the old
string.

**For stage 7 to verify, not to change:** the paywall screenshot shows
"Unlock Pro — £4.99", and that figure comes from
`integration_test/screenshots_test.dart`'s `_harnessPrice`, not from a store.
Stage 3 documented the choice and it is the right one — the constant is the
price the product *will* be created at, and the app itself still refuses to
invent a figure. But it stops being true the moment the console says anything
else. **Before upload, confirm `com.froggyeye.passportphoto.pro` is created at
the £4.99 price point and that App Store Connect renders it as `£4.99` in
en-GB**, then either recapture against the live product or accept the harness
figure knowingly. A screenshot quoting a price the store does not charge is a
rejection on both stores.

---

## 8. Pricing

**£4.99 one-time, non-consumable, `com.froggyeye.passportphoto.pro`. Settled —
this section is a sanity check, not a reopening.**

It sanity-checks well. Every anchor a user meets sits above it: a UK high-street
booth at £8–15 *per visit*, a rival's £19.99 unlock, and per-photo services at
$6.95–$16.95 *per set*. £4.99 once for unlimited photos and every country is the
cheapest credible offer in the category, and "cheapest credible" is a defensible
position precisely because the free tier is a working product rather than a
demo — the user has already watched the app get their photo right before they
are asked for anything.

**Price points to set:**

| Store | Setting |
|---|---|
| App Store | The **£4.99 / $4.99** price point (Apple's price-point grid, formerly Tier 5). Set the UK as the base and let Apple's local equivalents apply — €5.99 in the eurozone including VAT, and the regional adjustments Apple already calculates. Do not hand-edit territory prices at launch |
| Google Play | Base **£4.99**, auto-conversion on for all territories, with Play's purchasing-power-parity pricing left enabled — the visa audience is disproportionately in markets where it matters |

**Fees:** both stores take 15% on this app — Apple's Small Business Program
(Froggy Eye Ltd is far below the $1M threshold; confirm the app is enrolled) and
Play's automatic 15% on the first $1M. Net is roughly **£4.24** per unlock in
the UK. Budget accordingly in any projection.

**Launch pricing advice:** launch flat at £4.99 with no introductory offer. A
non-consumable cannot carry an introductory price anyway (that mechanism is
subscription-only); the equivalent would be a temporary promotional price, and
discounting an already-cheapest-in-category product mostly signals that the
normal price is negotiable. If anything, the risk here is being *under*-priced:
at £4.99 against a £19.99 rival, some buyers read the gap as a quality
difference. Do not act on that at launch — but §9's experiment 3 is worth
running once there are reviews to carry the price.

**Realistic expectations**, on the house's stated 3–8% band for a
well-positioned niche unlock. This app should land at the **upper** end when it
converts at all: the need is acute, the gate is a hard artefact, and the decision
happens at a moment of high intent. But installs, not conversion, are the
constraint — a zero-review app on a head term contested by 12k-rating incumbents
should expect single-digit organic installs per day at launch, growing with
reviews and long tails. At 20 installs/day and 6% conversion, that is roughly
**£150/month net**; at 60/day, roughly £450. Neither number justifies paid
acquisition, which is why §6 is entirely organic.

---

## 9. Verbatim block for release-manager

Copy these exactly. Everything below has been character-counted against the
store limits.

**Apple App Store**

- Name (30): `Passport Photo Studio` *(21)*
- Subtitle (30): `ID & visa photos. One payment.` *(30)*
- Keywords, en-GB (100): `booth,biometric,size,maker,crop,print,35x45,licence,child,baby,renewal,schengen,sheet,resize,uk` *(95)*
- Keywords, en-US (100): `booth,biometric,size,maker,crop,print,2x2,license,green,card,child,baby,renewal,sheet,resize,us` *(95)*
- Primary category: `Photo & Video` · Secondary: `Utilities`
- Age rating: 4+

**Google Play**

- Title (30): `Passport Photo Studio` *(21)*
- Short description (80): `Skip the booth. Passport, visa and ID photos checked against the spec.` *(70)*
- Category: `Photography`
- Content rating: Everyone

**Claims that are cleared for use in store text**

- "Your photo never leaves your phone." / "Your photo is never uploaded."
- "Checked against the country's own spec." / "Checked against the published spec."
- "No ads. No account."
- "One payment. No subscription."
- "Every country and document spec is free — nothing is locked."
- "30 document specs across 21 countries, plus ICAO Doc 9303 and Schengen
  generic fallbacks."
- "The app never retouches, beautifies or replaces the background — the photo
  stays the photo."

**Claims that must NOT appear anywhere in store text**

- Anything asserting the photo will be **accepted, approved, guaranteed or
  compliant** by any authority, including "approved first time".
- "No data collected", "no tracking", "everything runs offline", "no network",
  "we collect nothing" — all contradicted by the corrected privacy label (the
  bundled ML Kit SDK reports Device ID and diagnostics to Google). "Your photo
  never leaves your phone" remains true and is the claim to use instead.
- "Official", "government-approved", or any agency name (HMPO, DVLA, USCIS) used
  in a way that implies endorsement.
- "AI", "instant", "professional", "studio quality".
- Any competitor's app name, and any comparative price claim naming one.
- A currency figure for what a photo booth costs (dropped from shot 02 for
  exactly this reason — it does not travel across storefronts).

---

## 10. Experiments to run

1. **Keyword field iteration at day 30 and day 90.** Read App Store Connect's
   Search Terms report (store-side, no SDK) and swap the three lowest-impression
   terms for country tails from §2. The `35x45` / `2x2` split between
   localisations is the specific hypothesis to test first.
2. **Screenshot 01 vs 03 order**, once there is enough traffic to tell. The
   hypothesis in §5 is that outcome beats privacy at position one; it is a
   hypothesis, and Play's store listing experiments can settle it for free.
3. **£4.99 → £6.99 on Play only**, after 100+ ratings. Play's pricing
   experiments make this reversible and one-store-only. Do not run it before
   there are reviews to carry the higher price.
4. **The fallback name as the real name.** If `id photo` shows impressions but
   no conversions after 90 days, ship "Passport & ID Photo Studio" — it is a
   sanctioned fallback that happens to be the better ASO title.
5. **One spec page vs thirty.** Publish the UK page first and measure whether it
   ranks at all before generating all 30. If a single well-cited page cannot
   place for "UK passport photo size", the generator is not worth writing.

---

## 11. Risks to avoid

- **Drifting into an acceptance claim.** The whole category does it, it converts
  better, and it is the one thing that would make this app just another one of
  them — as well as a 2.3.1 metadata problem. Shot 01's old headline shows how
  easily it happens inside our own documents.
- **Re-asserting the withdrawn privacy claims.** They are gone from the label,
  the policy and now the screenshots, but they are exactly the sort of sentence
  that regrows in marketing copy because it sounds good. §9's forbidden list
  exists for that reason.
- **Competing on country count.** We lose that comparison and drawing attention
  to it invites it.
- **Adding ads.** Not just off-brand — the current listing claims "No ads", the
  privacy label has no advertising identifier in it, and reversing that would
  require re-declaring both stores' labels and would cost more trust than the
  revenue is worth on a £4.99 app.
- **Gating a country to raise ARPU.** The free tier's credibility is load-bearing
  (§5, shot 04). The first locked country turns us into the apps we are
  positioned against.
- **Building engagement mechanics** into a once-a-decade utility. See §6.5.

---

## 12. Longer-term revenue

**0–6 months.** Ship 1.0. Get the listing right, get the review prompt into 1.1,
publish the spec pages, and let ASO compound. No spend.

**6–18 months.** Add specs where the storefront data says the demand is, and add
localised store metadata for the markets whose specs we already ship — each is a
new indexed keyword field for the cost of a translation. The print-service
handoff (Boots, Walgreens, FedEx) is the first feature that could carry a second
revenue line, though as an affiliate arrangement rather than a second IAP; it
must not compromise the on-device story.

**18+ months.** The only defensible second product here is **B2B**: small travel
agencies, post-office counters and visa-service shops are already a named target
user, and they do this dozens of times a week on someone else's phone. A
per-seat or per-site licence sold through the same non-consumable mechanism, or
a separate SKU, is a genuinely different customer with a genuinely different
willingness to pay — and it needs nothing the app does not already do except
volume-friendly export. That is the direction to explore before ever
reconsidering a subscription, which this product does not justify: there is no
ongoing cost, no ongoing content, and no ongoing use.
