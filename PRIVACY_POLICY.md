# Privacy Policy — Passport Photo Studio

**Last updated: 28 August 2026**

Passport Photo Studio is published by **Froggy Eye Ltd** (United Kingdom).

## The short version

**Your photo never leaves your device.** Passport Photo Studio has no servers
and no accounts, and we — Froggy Eye — receive no data about you at all.

Two components built by Apple and Google are bundled inside the app, and both
of them do use the network. One checks whether you have paid; the other is the
face-detection library, which sends Google its own diagnostics. Neither sends
your photograph. The detail is below, because "we collect nothing" would be
easier to say than it is to defend, and you should be able to check.

## What the app does with your photos

When you take a photo or choose one from your library, the app reads it,
detects the face on your device using Google's ML Kit — an offline library
whose model is bundled with the app — crops and scales it to the document
specification you selected, and shows you the result.

That processing happens in the app, on your phone. **No image is uploaded
anywhere, by us or by anyone else.** The face detection runs against a model
file inside the app; there is no server involved in it and none of your
photograph is transmitted.

The image is held in memory while you are looking at it. The source photo — the
copy the camera or the photo picker hands the app — is deleted as soon as the
app has finished with it, and anything left behind by a crash is cleared the
next time the app starts. The only copies that persist are the ones you
explicitly save to your own photo gallery.

## Face data

Because the app detects a face in your photo, this section states exactly what
happens to face data, in the terms privacy laws and the app stores use.

**What face data is processed.** To centre and size the crop, the app runs
Google ML Kit's on-device face detection over your photo. That produces a face
bounding box and the positions of facial landmarks (such as the eyes) as
coordinates in the image. The app reduces those coordinates to simple geometric
measurements — face height, eye-line position — and uses them for two things
only: cropping the photo to the document specification you chose, and running
the compliance checks shown on the result screen.

**No face data is collected, stored, or shared.** The detection runs entirely
on your device against a model bundled inside the app. The bounding box,
landmark coordinates and derived measurements exist only in the app's working
memory while your photo is being processed and displayed; they are discarded
when processing finishes and are never written to disk, never included in any
saved file, never transmitted off your device, and never shared with us or with
any third party. ML Kit's diagnostic reports to Google (described below)
contain no face data and no part of your image.

**No recognition, no identification, no profiling.** The app performs face
*detection* — "where is a face in this picture" — not face *recognition*. It
creates no faceprint or biometric template, cannot identify anyone, does not
compare faces across photos, and builds no database of faces.

**Retention: none.** Face data is retained only for the seconds your photo is
being processed and viewed, in memory, on your device. There is nothing for us
to retain — we never receive it. The only face-related thing that can persist
is the finished photograph itself, and only if you choose to save it to your
own photo library.

## What uses the network

The app makes no requests of its own. It has no server to talk to and contains
no code that contacts one. Two bundled components do use the network:

- **The store's in-app purchase library** (Apple's or Google's), to check
  whether you own Passport Photo Studio Pro. It sends no photo and nothing
  about what you do in the app.

- **Google's ML Kit**, the offline face-detection library. The detection itself
  runs entirely on your device against a model bundled inside the app — your
  photo is never sent anywhere. ML Kit does, however, send Google its own
  diagnostic and usage data: a non-advertising device identifier, performance
  and error information, and counts of which of its features ran. We do not
  receive that data, we cannot see it, we cannot switch it off, and it contains
  no part of your photograph. Google processes it under its own privacy policy:
  https://policies.google.com/privacy

## What is stored on your device

- The last document specification you chose, so the app opens where you left
  off.
- Whether you have purchased Passport Photo Studio Pro.

Both are stored in the app's own private storage on your device. Uninstalling
the app removes them. Neither is transmitted anywhere.

## Permissions

- **Camera** — so you can take a photo in the app. Optional; you can import an
  existing photo instead.
- **Photo library (read)** — so you can choose an existing photo to crop.
- **Photo library (add)** — so the finished photo and print sheet can be saved
  back to your library.

The app asks for nothing else. It does not request location, contacts, the
microphone, or background access.

## Purchases

Passport Photo Studio Pro is a one-time purchase handled entirely by Apple's
App Store or Google Play. We never see or store your payment details. The
stores tell the app only whether the purchase exists; the record of it lives in
your store account, which is why "Restore purchase" works on a new device.

Apple and Google process that transaction under their own privacy policies:

- Apple: https://www.apple.com/legal/privacy/
- Google: https://policies.google.com/privacy

## Analytics, advertising and tracking

**We do not track you.** The app contains no advertising SDK, does not use your
advertising identifier, does not ask for permission to track you across other
apps or websites, and builds no profile of you. Nothing you do in the app is
reported to us — we have added no analytics and no crash reporting of our own,
so we could not see it even if we wanted to.

The one qualification, and it is the reason this section is not simply "there
are none": Google's ML Kit carries its own usage-analytics client, described in
the section above. It reports to Google, not to us, about how the library
itself performed. It is not used for advertising and it is not linked to your
identity, but it is analytics, and calling the app analytics-free would not be
true.

## Children

We collect no data from anyone, including children. The app has no accounts, no
social features and no advertising.

## Your rights

Because we hold no data about you, there is nothing for us to disclose,
correct, export or delete. Everything the app knows about you is on your device
and under your control — deleting the app deletes it.

For the diagnostic data ML Kit sends Google, Google is the data controller and
your rights are exercised through them, under the policy linked above.

## Changes to this policy

If this policy changes, the updated version will be published at this address
with a new "last updated" date.

## Contact

Questions about this policy: **info@froggyeye.com**

Froggy Eye Ltd, United Kingdom
https://froggyeye.com

© 2026 Froggy Eye Ltd
