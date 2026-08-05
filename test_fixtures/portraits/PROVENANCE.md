# Test portraits — provenance

These five 1024×1024 JPEGs are **synthetic faces**. They are StyleGAN2 output
(Karras et al., NVIDIA), fetched on 2026-08-05 from
`https://thispersondoesnotexist.com/random-person.jpeg`, which serves a freshly
generated image on every request. Each file carries the generator's own
"StyleGAN2 (Karras et al.)" watermark in the bottom-right corner.

**No image here depicts a real person.** That is the reason this source was
chosen over a stock-photo library: the QA harness needs faces realistic enough
for ML Kit's detector to find landmarks on, and a generated face carries no
individual's likeness and therefore needs no model release.

They exist only so `integration_test/crop_geometry_probe_test.dart` can run the
real detection-and-crop pipeline against something ML Kit will actually detect.
They are **not** Flutter assets — they are not listed in `pubspec.yaml`, so they
are absent from every build of the app. The probe reads them from an absolute
host path, which works because an iOS Simulator process shares the Mac's
filesystem.

If they ever need regenerating, any set of generated head-and-shoulders
portraits will do; the probe re-derives its own framing from the detected face
box, so it does not depend on these particular images.

Do not replace these with photographs of real people. `docs/TEST_PLAN.md`
records the same constraint.
