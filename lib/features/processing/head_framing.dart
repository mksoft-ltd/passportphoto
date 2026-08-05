import 'dart:math' as math;

import '../../core/models/photo_spec.dart';

/// Where the head goes in the finished photo, as fractions of the photo height
/// measured down from the top edge.
///
/// A document photo has to satisfy two independent rules at once: the head must
/// measure a stated height, and the eye line must sit a stated distance up from
/// the bottom edge. For a real head — whose eyes fall roughly half way between
/// chin and crown — several of the bundled specs cannot honour both rules at
/// their stated midpoints without pushing the crown off the top edge.
/// `uk_passport` is the clearest case: 29–34 mm of head with the eye line
/// 30–36 mm up a 45 mm photo leaves the crown flush against the top edge even at
/// the most forgiving end of both bands, and nothing is left over for a margin.
///
/// So the conflict is resolved deliberately here rather than falling out of the
/// arithmetic somewhere downstream. Priorities, highest first:
///
///  1. **The whole head is inside the frame**, clear of both edges. A photo with
///     the chin cut off is refused at the counter and no other property of it
///     matters. This is never traded away.
///  2. **The head height stays inside the spec's band.** It is the one rule
///     every issuing authority publishes and actually measures.
///  3. **The eye line sits inside the spec's band**, as near the middle of it as
///     the two rules above permit.
///
/// When rule 3 cannot be met the eye line is placed as close to the spec's band
/// as the framing allows, rather than the crop silently sacrificing rule 1.
class HeadFraming {
  const HeadFraming({
    required this.faceHeightFraction,
    required this.eyeLineFromTopFraction,
    required this.honoursSpecEyeLine,
  });

  /// Chin-to-crown as a fraction of the photo height.
  final double faceHeightFraction;

  /// Eye line as a fraction of the photo height, measured down from the top.
  final double eyeLineFromTopFraction;

  /// False when the framing had to place the eye line outside the spec's own
  /// band to keep the whole head in the picture.
  final bool honoursSpecEyeLine;

  /// Crown position, as a fraction down from the top edge.
  double crownFraction(double eyeLineWithinHead) =>
      eyeLineFromTopFraction - eyeLineWithinHead * faceHeightFraction;

  /// Chin position, as a fraction down from the top edge.
  double chinFraction(double eyeLineWithinHead) =>
      eyeLineFromTopFraction + (1 - eyeLineWithinHead) * faceHeightFraction;

  /// Clear space kept above the crown.
  static const double crownMargin = 0.04;

  /// Clear space kept below the chin. Larger than [crownMargin] because the
  /// space under the chin is the neck and shoulders, and a document photo that
  /// ends at the jaw reads as a crop rather than a portrait.
  static const double chinMargin = 0.08;

  /// Where the eyes sit in a head, as a fraction of chin-to-crown measured down
  /// from the crown, when the detector gives no better answer.
  ///
  /// The classical "eyes half way down the head" figure, nudged up slightly:
  /// measured against the five reference portraits the eye line came out at
  /// 0.51 of the head height with the crown taken from
  /// `PhotoProcessor.headHeightFactor`.
  static const double nominalEyeLineWithinHead = 0.45;

  /// Solves the framing for [spec], given where this particular subject's eyes
  /// sit within their head ([eyeLineWithinHead], a fraction of chin-to-crown
  /// measured down from the crown).
  ///
  /// Taking the eye position as an input rather than assuming it is what lets
  /// the same rules hold for a subject with a tall forehead and one without.
  factory HeadFraming.forSpec(
    PhotoSpec spec, {
    required double eyeLineWithinHead,
  }) {
    final e = eyeLineWithinHead.clamp(0.2, 0.8);

    final faceMin = spec.faceHeightMinFraction;
    final faceMax = spec.faceHeightMaxFraction;
    final facePreferred = spec.targetFaceHeightFraction;

    // The spec states the eye line up from the bottom; the crop works down from
    // the top, so the band arrives reversed.
    final eyeMin = 1 - spec.eyeLineFromBottomMaxFraction;
    final eyeMax = 1 - spec.eyeLineFromBottomMinFraction;
    final eyePreferred = 1 - spec.targetEyeLineFromBottomFraction;

    // The largest head that still leaves the eye line somewhere inside its own
    // band with both crown and chin clear of the edges. A smaller head buys
    // room at both edges, so shrinking towards it is how rule 3 gets satisfied
    // when the preferred size alone would not allow it.
    final capForSpecEyeLine = math.min(
      (eyeMax - crownMargin) / e,
      (1 - chinMargin - eyeMin) / (1 - e),
    );

    var face = math.min(facePreferred, capForSpecEyeLine);
    if (face < faceMin) {
      // Even the smallest legal head cannot get the eye line into its band —
      // the spec's two bands contradict each other for a head of this shape.
      // Rule 2 outranks rule 3, so take the preferred size back and let the eye
      // line be the thing that gives. Shrinking the head here would cost face
      // height without buying the compliance it was meant to buy.
      face = facePreferred;
    }
    face = face.clamp(faceMin, faceMax);
    // Rule 1 outranks rule 2: a head that cannot fit between the margins at any
    // legal size is shrunk below its band, and the face-size check reports it.
    const absoluteCap = 1 - crownMargin - chinMargin;
    if (face > absoluteCap) face = absoluteCap;

    // With the head sized, the eye line can only move within the range that
    // keeps both ends of the head off the edges.
    final framingMin = crownMargin + e * face;
    final framingMax = 1 - chinMargin - (1 - e) * face;

    final wantMin = eyeMin > framingMin ? eyeMin : framingMin;
    final wantMax = eyeMax < framingMax ? eyeMax : framingMax;

    final double eyeLine;
    final bool honoured;
    if (wantMin <= wantMax) {
      eyeLine = eyePreferred.clamp(wantMin, wantMax);
      honoured = true;
    } else {
      // The spec's eye band and the framing have no overlap. Sit at whichever
      // end of the framing range is nearest the band.
      eyeLine = eyePreferred.clamp(framingMin, framingMax);
      honoured = false;
    }

    return HeadFraming(
      faceHeightFraction: face,
      eyeLineFromTopFraction: eyeLine,
      honoursSpecEyeLine: honoured,
    );
  }

  @override
  String toString() => 'HeadFraming(face: ${faceHeightFraction.toStringAsFixed(3)}, '
      'eyeFromTop: ${eyeLineFromTopFraction.toStringAsFixed(3)}, '
      'specEyeLine: ${honoursSpecEyeLine ? 'honoured' : 'unreachable'})';
}
