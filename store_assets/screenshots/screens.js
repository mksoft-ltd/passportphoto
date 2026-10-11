// The store screenshot set, in marketing order. This is the machine-readable
// twin of ../screenshot_specs.md — change both together.
//
// `state` is what the capture must show. The screenshot harness
// (--dart-define=SCREENSHOT_MODE=true) already seeds the UK passport spec, a
// finished crop with all seven checks green, and the Pro entitlement; anything
// beyond that is navigation the capture script has to perform.
//
// Copy last reviewed in stage 5 (docs/ASO.md §5). Two rules that are not
// negotiable and are easy to undo by accident: no headline may promise that a
// photo will be accepted/approved, and nothing here may claim "no tracking",
// "runs offline" or "no data collected" — the privacy label declares ML Kit's
// device ID and diagnostics.
window.PPS_SCREENS = [
  {
    slug: '01_result',
    screen: 'Review (/result)',
    headline: 'Every check before you print',
    accent: 'Every check',
    sub: 'Pass or fail on face size, eye line and background.',
    state:
      'UK passport spec, the seeded crop on screen at 35×45 mm, and the ' +
      'compliance card reading "7 / 7 passed" with every row green. Scrolled ' +
      'so the photo and the whole checklist are both in frame.',
  },
  {
    slug: '02_sheet',
    screen: 'Print sheet (/sheet)',
    headline: 'Skip the photo booth',
    accent: 'photo booth',
    sub: 'Print a 4×6" sheet at any counter — booths charge far more.',
    state:
      'The 4×6" sheet preview, Pro unlocked so it renders unwatermarked: the ' +
      'tiled UK photos at 300 dpi with their cutting gaps, and the "Save ' +
      'print sheet" button visible.',
  },
  {
    slug: '03_home',
    screen: 'Home (/)',
    headline: 'Your photo never leaves your phone',
    accent: 'never leaves your phone',
    sub: 'No ads. No account. Your photo is never uploaded.',
    state:
      'Home with the UK passport spec selected in the document card, both ' +
      'source-photo tiles enabled, and the footer line "All processing ' +
      'happens on your device. No photos leave your phone." in frame.',
  },
  {
    slug: '04_picker',
    screen: 'Country & document picker (/picker)',
    headline: 'Every country, free',
    accent: 'free',
    sub: 'Passport, visa and ID specs — nothing behind the paywall.',
    state:
      'The picker at the top of the unfiltered list, search field empty, so ' +
      'the breadth of countries reads at a glance and the UK row shows as ' +
      'selected. No lock badges anywhere — specs are never gated.',
  },
  {
    slug: '05_pro',
    screen: 'Paywall (/pro)',
    headline: 'One payment. No subscription.',
    accent: 'No subscription.',
    sub: 'Unlock full-resolution exports and the print sheet. Once.',
    state:
      'The paywall in its PRE-PURCHASE state — the free-vs-Pro table, the ' +
      '"Paid once, yours for good" card and an "Unlock Pro — <price>" button ' +
      'showing a real store price. Needs the entitlement overridden to ' +
      'locked; see §1 of screenshot_specs.md.',
  },
];

// Canvas sizes, one per store target. The stores auto-scale down from these.
//
// `device` is the width of the phone bezel on the 1080-unit artboard. It is
// per-platform because the capture is scaled to the frame's *width* and the
// surplus height is clipped (see screenshot.css) — so this width is what
// decides how much of the screen survives. Too narrow and the device stops
// bleeding off the bottom and floats; too wide and the bottom of the app is
// cut off. Re-check the rendered set if any canvas size here changes.
//
// No iPad set: the app ships TARGETED_DEVICE_FAMILY = 1.
window.PPS_PLATFORMS = {
  // 940 rather than 900: at 900 an iPhone capture ends within ~30 units of the
  // canvas bottom, so any headline that wraps to a third line would leave the
  // device floating above the edge instead of bleeding off it.
  ios69: { w: 1320, h: 2868, label: 'iPhone 6.9"', raw: 'ios', device: 940 },
  ios67: { w: 1290, h: 2796, label: 'iPhone 6.7"', raw: 'ios', device: 940 },
  android: { w: 1080, h: 1920, label: 'Play phone', raw: 'android', device: 830 },
};
