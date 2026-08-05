import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/crop_harness.dart';
import 'support/specs.dart';

/// `PhotoProcessor.process` must not run its image work on the calling isolate.
///
/// Decode, EXIF bake, crop, cubic resample and JPEG encode of a full-resolution
/// camera still measured **679 ms on an Apple Silicon Mac**, which extrapolates
/// to roughly 1.5-3 s on a phone. On the UI isolate that is not a slow loading
/// state, it is a frozen frame: `ResultScreen` renders a
/// `CircularProgressIndicator` and "Detecting face & cropping…" while it runs,
/// and a blocked isolate cannot animate them. On a slow Android device it also
/// approaches the 5 s ANR threshold. This is the app's central interaction and
/// it happens to every photo.
///
/// The test measures the property rather than the implementation: a periodic
/// timer on this isolate is left running across the call, and its callbacks can
/// only fire while the isolate is free. If the pipeline is moved back inline,
/// the tick count collapses.
void main() {
  test('the image pipeline leaves the calling isolate free to run', () async {
    var ticks = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 5), (_) => ticks++);

    final sw = Stopwatch()..start();
    await runProcessor(spec: ukPassport());
    sw.stop();
    timer.cancel();

    // A 5 ms timer across work this size yields tens to hundreds of ticks when
    // the isolate is free. Blocked, Dart does not replay the missed intervals —
    // it fires once on the way out — so anything in single figures means the
    // work came back onto this isolate. The bar is deliberately far below the
    // expected count and far above the blocked count.
    expect(
      ticks,
      greaterThan(10),
      reason: 'only $ticks timer ticks fired during ${sw.elapsedMilliseconds}ms '
          'of processing — the image pipeline is blocking the calling isolate '
          'again, which on the UI isolate is a frozen spinner',
    );
  });
}
