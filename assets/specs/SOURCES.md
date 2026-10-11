# Where the numbers in `photo_specs.json` come from

Last verified: **2026-08-05**. Data version 2. Spain re-verified **2026-10-11** (data version 4).

This file exists because the app's headline claim is that its 30 specs match
what issuing authorities actually publish. That claim is only as good as its
provenance, and one figure in version 1 was wrong in a way that took a
geometric argument to notice. If you change a number in `photo_specs.json`,
change the corresponding row here in the same commit.

---

## The version 1 error, recorded so it is not reintroduced

Every 35 × 45 mm spec stated the eye line at **30–36 mm from the bottom** of a
45 mm photo — 67–80% of the picture height. No issuing authority anywhere
publishes that.

The upper bound is the tell: **80% of 45 mm is exactly 36 mm**. ICAO, Germany,
Australia and Japan all publish the *head height* (chin to crown) as 70–80% of
the image height, which on a 45 mm photo is 31.5–36 mm. The head-height band
had been copied into the eye-line field.

The geometry confirms it. Eyes 36 mm up a 45 mm photo, a 34 mm head, eyes
sitting roughly 47% of the way up the head from the chin: the chin lands at
20 mm and the crown at **54 mm on a 45 mm photo** — 9 mm above the top edge.
The figure describes a photograph that cannot exist.

---

## The rule this data now follows

1. **If the issuing authority publishes an eye-line figure, use it verbatim.**
   Exactly one does: the United States.
2. **Otherwise derive the band from ICAO's published portrait geometry** and
   label it derived. No guessing, no third-party photo-service websites.
3. **Head height comes from the national authority** where one publishes it,
   and from ICAO otherwise.

### The derived eye-line band

ICAO's technical report *Portrait Quality (Reference Facial Images for MRTD)*
§5.4 Table 9 gives the vertical eye position as **Mv/B between 30% and 50%**,
where Mv is the distance from the top of the image to the midpoint of the eyes
and B is the image height. Measured from the bottom — the convention every
issuing authority states it in, and the convention this app's field names use —
that is **50% to 70% of the image height**.

- Source: <https://www.icao.int/sites/default/files/TRIP/Publications/TR-Portrait-Quality-v1.0.pdf>
- The report's own revision log states its content is taken from
  **ISO/IEC 19794-5** (Face Image Data). ISO/IEC 19794-5 is paywalled, so ICAO's
  reproduction is the citable public source. Cite it as such — we have not read
  the ISO text directly.

**Corroboration**: the United States, the one authority that does publish a
figure, requires the eye line at **56–69% of image height from the bottom**.
That sits inside ICAO's 50–70% band. Two independent authorities agreeing is
the strongest evidence available that 50–70% is the real envelope.

**Why not tighten to the US 56–69%?** Because 56–69% is US law and applies to
US photographs. Applying it to other countries would invent a strictness no
authority asked for and would fail crops that are genuinely compliant.

### What ICAO Doc 9303 itself does *not* say

Doc 9303 Part 3 §3.9.1 requires the crown-to-chin portion to be **70–80% of the
longest dimension of Zone V**. Two traps in that sentence:

- It is **crown-to-chin**, not an eye line. Doc 9303's only eye figures are
  inter-eye distance (≥ 10 mm) and eye-to-mouth distance.
- **Zone V is the printed portrait window on the passport data page**, not the
  photograph the applicant submits. Conflating the two is how national bands
  that sit below 70% (the UK's 29–34 mm = 64–76%) come to look like errors when
  they are not.

Source: <https://www.icao.int/sites/default/files/publications/DocSeries/9303_p3_cons_en.pdf>

---

## Per-spec provenance

### Eye line — published

| Specs | Band | Source |
|---|---|---|
| `us_passport`, `us_visa` | **28–35 mm** on 51 mm (56–69%) | travel.state.gov photo requirements: *"Eye height, measured from the bottom of the image to the level of the eyes: between 56% and 69% of the image's height"*, i.e. 1⅛–1⅜ inch. <https://travel.state.gov/en/passports/apply/help/photos.html> |

### Eye line — derived from ICAO TR Table 9 (50–70% of image height)

Every other spec. No national authority among them publishes an eye-line
figure in millimetres or percent; this was checked individually, not assumed.

| Photo height | Derived band | Specs |
|---|---|---|
| 45 mm | 22.5–31.5 mm | `icao_generic`, `uk_passport`, `uk_visa`, `schengen_generic`, `de_passport`, `de_id`, `fr_passport`, `nl_passport`, `se_passport`, `ch_passport`, `jp_passport`, `mx_passport`, `za_passport`, `ie_passport`, `au_passport`, `nz_passport`, `sg_passport`, `us_drivers_license` |
| 51 mm | 25.5–35.7 mm | `in_passport`, `in_visa` |
| 70 mm | 35–49 mm | `ca_passport`, `ca_id`, `br_passport` |
| 40 mm | 20–28 mm | `it_passport` |
| 48 mm | 24–33.6 mm | `cn_passport`, `cn_visa` |
| 55 mm | 27.5–38.5 mm | `ae_passport` |
| 32 mm | 16–22.4 mm | `es_passport` (photo is 26 × 32 mm, portrait — see "Spain" below) |

Authorities checked for an eye-line figure and confirmed **not to publish one**:
UK HMPO, Germany (BMI/Bundesdruckerei), Canada (IRCC), Australia (APO), New
Zealand (DIA), Netherlands (RvIG), Switzerland (fedpol), Japan (MOFA), China,
South Africa (DHA), Italy (Polizia di Stato), India, Singapore (ICA), Ireland
(DFA), Mexico (SRE), and the EU for Schengen visas.

Two authorities publish an eye *zone* as a graphic on a physical overlay
template with no millimetre value printed on it — Germany's older
*Passbild-Schablone* and the Netherlands' *Fotomatrix* — which is not a figure
this app can encode.

### Head height (chin to crown)

Published nationally, unchanged in version 2:

| Spec(s) | Band | Source |
|---|---|---|
| `uk_passport`, `uk_visa` | 29–34 mm | gov.uk photo requirements; HMPO caseworker guidance *Photo standards v51.0* (19 Jan 2026): *"must measure between 29 mm and 34 mm from the crown (top) of head to the bottom of chin"* |
| `us_passport`, `us_visa` | 25–35 mm | travel.state.gov: 1 to 1⅜ inch, top of hair to bottom of chin |
| `ca_passport`, `ca_id` | 31–36 mm | IRCC passport photo specifications (canada.ca) |
| `au_passport` | 32–36 mm | Australian Passport Office photo guidance |
| `jp_passport` | 32–36 mm | MOFA: 34 ± 2 mm crown to chin |
| `cn_passport`, `cn_visa` | 28–33 mm | Chinese embassy passport/visa photo requirements |
| `za_passport` | 29–34 mm | DHA photograph specifications |
| `de_passport`, `de_id`, `fr_passport`, `se_passport`, `schengen_generic`, `icao_generic`, `mx_passport`, `nz_passport`, `sg_passport`, `ie_passport`, `ae_passport`, `br_passport`, `in_*`, `us_drivers_license` | as bundled | ICAO 70–80% or the national figure already carried from version 1; not re-derived this pass |

**Corrected in version 2**, each against the country's own published template:

| Spec | Was | Now | Source |
|---|---|---|---|
| `nl_passport` | 32–36 mm | **26–30 mm** | RvIG *Fotomatrix 2020* — 26–30 mm chin to crown for applicants aged 11+. The Netherlands genuinely requires a smaller head than the ICAO generic; 32–36 mm was an assumption, not the Dutch rule. <https://www.rvig.nl/sites/default/files/2023-02/Fotomatrix%202020.pdf> |
| `ch_passport` | 32–36 mm | **29–34 mm** | fedpol Fotomustertafel — 29–34 mm chin to crown. <https://www.fedpol.admin.ch/dam/de/sd-web/ZA--3ny9zRWt/fotomustertafel.pdf> |
| `it_passport` | 32–36 mm | **28–32 mm** | Polizia di Stato photo guidance states the face as 70–80% of the photo; on Italy's 40 mm photo that is 28–32 mm. The bundled 32–36 mm was the 45 mm group's figure applied to a 40 mm photo, which is 80–90% — outside every published envelope, and the direct cause of `it_passport` being the one spec whose two bands could not both be satisfied. <https://www.poliziadistato.it/statics/10/fotografia_passaporto_web.pdf> |

**Corrected in version 4 (2026-10-11, app 1.0.3):**

| Spec | Was | Now | Source |
|---|---|---|---|
| `es_passport` | 32 mm wide × 26 mm tall; head 18–22 mm; eye line 13–18.2 mm | **26 mm wide × 32 mm tall**; head **22.4–25.6 mm** (ICAO 70–80% of 32 mm); eye line **16–22.4 mm** (ICAO TR Table 9, 50–70% of 32 mm) | See "Spain" below |

### Spain

What the authority actually publishes, read directly on 2026-10-11:

- **DNI** — Real Decreto 255/2025, de 1 de abril, art. 6.2.d) 4.º: *"Una
  fotografía reciente del rostro de la persona solicitante en color, tamaño 32
  por 26 milímetros, con fondo uniforme blanco y liso, tomada de frente, con la
  cabeza totalmente descubierta y sin gafas de cristales oscuros…"*
  <https://www.boe.es/buscar/act.php?id=BOE-A-2025-6601>
- **Passport** — Policía Nacional, *Requisitos para la obtención* (citing Real
  Decreto 896/2003, art. 4): *"Una fotografía reciente en color del rostro del
  solicitante, tamaño 32 x 26 milímetros, con fondo uniforme blanco y liso,
  tomada de frente…"*
  <https://www.dnielectronico.es/PortalDNIe/PRF1_Cons02.action?pag=REF_1084&id_menu=56>

Neither text says which figure is the height. Version 1 read "32 por 26" as
width-first and shipped a **landscape** 32 × 26 mm photo — the only spec in the
set wider than it is tall. It is read here as 32 mm tall × 26 mm wide, because:

1. It is a frontal head-and-shoulders portrait under ICAO Doc 9303, and every
   other document photo in the world that rule governs is portrait or square.
2. On a 26 mm-tall frame the old 18–22 mm head band was 69–85% of the
   height — above ICAO's 80% ceiling at the top end. The landscape reading
   only fit the data by bending it.
3. Spain's own consular guidance (Consulado General de España en Nador,
   *Expedición de pasaportes ordinarios*) gives *"tamaño aproximado 32 x 26 mm,
   aunque la anchura puede llegar a 40 mm"* — width is the figure allowed to
   grow, which reads naturally only if the base is portrait.

This is a reading of an unoriented figure, not a quotation of one, and is
labelled as such. Spain publishes no head-height or eye-line figure, so both
bands follow rule 2 and 3 above (ICAO-derived). `test/photo_spec_test.dart`
pins the orientation, and also pins that no bundled spec is wider than it is
tall, so a transposed figure cannot come back silently.

---

## Known contradictions in the published sources

Recorded because they are real, they are not this app's mistakes, and the next
person to check this data will otherwise rediscover them.

1. **Germany measures the same 32–36 mm to two different landmarks.** The
   current *Fotomustertafel* says chin to the top of the head
   (*"Kinnspitze bis zum oberen Kopfende"*); the older *Passbild-Schablone* says
   chin to the **hairline** (*"vom Kinn bis zum Haaransatz"*). Same number,
   different measurement. The app models chin-to-crown.
2. **UK HMPO's caseworker manual states a vertical eye band** — eyes in the
   "top 40% to 70% of the photo" — that only partly overlaps ICAO's 50–70% from
   the bottom. It is framed as a tolerance for HMPO's face detector, not as a
   compositional requirement, so ICAO's band is used and HMPO's is not encoded.
3. **The UK's 29–34 mm head height (64–76%) sits below ICAO's 70% floor.** Not
   a conflict: ICAO's 70–80% governs the printed data-page portrait, not the
   submitted photograph. See the Doc 9303 note above.
4. **National figures use different landmarks.** Chin-to-crown for AU, NL, CH,
   JP, CN, CA; chin to the top of the *hair* for the US and New Zealand; "the
   face" as a percentage for Italy and India. Percentages must not be moved
   between specs without checking which landmark they measure to.
5. **No EU-level numeric Schengen photo annex could be found.** The widely
   repeated "Schengen 32–36 mm" figure appears only on third-party photo
   websites, which attribute it to ICAO — i.e. it is the 70–80% head-height rule
   restated. `schengen_generic` is therefore ICAO-derived, not independently
   published, and is labelled generic in the app for that reason.

## Sources deliberately not used

Third-party passport-photo services (visafoto, passport-photo.online,
123passportphoto and similar) were read for corroboration only and are cited
nowhere in this file. They copy each other, and the 30–36 mm eye-line figure
this version removes is the kind of error that propagates through them.

## Verification note

`travel.state.gov` and `canada.ca` block automated fetches (Cloudflare). Their
figures above were retrieved through domain-restricted search, which surfaces
the official text but is a weaker citation than a direct read. Both are worth
re-checking by hand in a browser before a release that changes them.

---

# Background, glasses and head coverings

Added 2026-09-19, data version 3. Until then this file covered only the
geometry, and `photo_specs.json`'s `background` values and the `notes` strings
that assert things like "No glasses" carried **no provenance at all** — which
broke this file's own opening rule.

## Why the backgrounds are not all white

The common assumption is that a passport photo needs a white background. It
does not, and for several of these countries white is the wrong answer:

| Authority | Published wording | Source |
|---|---|---|
| UK (HMPO) | "be taken against a plain light-coloured background" | <https://www.gov.uk/photos-for-passports> |
| US (State Dept) | white or off-white | <https://travel.state.gov/en/passports/apply/help/photos.html> |
| Canada (IRCC) | "a plain white or light-coloured background" | <https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/photos.html> |
| Germany (Auswärtiges Amt) | "The background should be neutral and light, providing sufficient contrast to the face and hair (a neutral grey)." | <https://dublin.diplo.de/ie-en/passport-photos-2380534> |
| China (visa) | "Background should be in white, and with no edge frame." | <https://losangeles.china-consulate.gov.cn/eng/visa/chinavisa/201611/t20161122_5421687.htm> |

So `uk_passport`'s off-white and the German/Dutch/French light grey are
correct, not a bug. Germany in particular commonly rejects pure white.

## Glasses and head coverings

`glasses` and `headCovering` in `photo_specs.json`. **Neither is checked
automatically and neither can be**: `google_mlkit_face_detection`'s `Face`
carries head Euler angles, eye-open and smiling probabilities, landmarks and
contours, and nothing about eyewear or headwear. They are published to the
user as rules to follow, in `_AccessoryRulesCard` on the result screen, kept
visually apart from the seven measured checks.

**Fetched from the authority's own page:**

| Spec | Glasses | Source |
|---|---|---|
| `uk_passport`, `uk_visa` | Only if you have to; no tinted; eyes not covered, no glare | <https://www.gov.uk/photos-for-passports> |
| `ca_passport`, `ca_id` | Accepted; eyes clearly visible, no glare; no sunglasses or tint | <https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/photos.html> |
| `de_passport`, `de_id` | Allowed; no reflection, frames must not hide the eyes | <https://dublin.diplo.de/ie-en/passport-photos-2380534> |
| `cn_visa` | "Eyeglasses are allowed except thick-rimmed, tinted or glare glasses." | <https://losangeles.china-consulate.gov.cn/eng/visa/chinavisa/201611/t20161122_5421687.htm> |

**Search-sourced, citing the authority but not fetched from it** (the sites
either 403 the request or publish the rules inside an image). Treated the same
as the above in the data — they are unambiguous and long-standing — but noted
here so the distinction is not lost:

| Spec | Glasses | Authority |
|---|---|---|
| `us_passport`, `us_visa` | Must be removed; none accepted since 1 Nov 2016 bar a signed medical statement | travel.state.gov |
| `au_passport` | Should not be worn; rare medical exemption with certificate | passports.gov.au |
| `nz_passport` | Prescription allowed if not tinted or thick-framed | passports.govt.nz |
| `in_passport`, `in_visa` | To be removed; no tinted or dark glasses | passportindia.gov.in |
| `sg_passport` | Prefers none; clear untinted thin frames accepted | ica.gov.sg |

**Not confirmed** — every other spec carries `"glasses": "unverified"` and
`"headCovering": "unverified"`, and the app says so on screen rather than
guessing. That covers `icao_generic`, `schengen_generic`, `fr_passport`,
`es_passport`, `it_passport`, `nl_passport`, `se_passport`, `ch_passport`,
`ie_passport`, `jp_passport`, `cn_passport`, `ae_passport`, `br_passport`,
`mx_passport`, `za_passport` and `us_drivers_license`. Filling these in is
worth doing; inventing them is not.

Note `cn_passport` is deliberately left unverified even though `cn_visa` is
sourced: the consulate page above is the **visa** rule, and the passport, which
China issues to its own nationals, is a different instrument. The secondary
sources that claim glasses are banned for it do not agree with each other.

## Neutral expression

Not a background or accessory rule, but recorded here because it came out of
the same review. Almost every spec's `notes` asks for a neutral expression or
"no smiling", ML Kit returns `smilingProbability` on every detection, and
nothing read it until 2026-09-19. It is now the report's eighth check.
