import 'package:flutter/material.dart';

import '../../core/models/photo_spec.dart';
import '../processing/head_framing.dart';

/// Translucent overlay with a face oval cutout sized to roughly match
/// the spec's face-to-frame proportion. Helps users frame correctly before
/// they snap the photo.
class FaceOverlay extends StatelessWidget {
  const FaceOverlay({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _FaceOverlayPainter(spec: spec),
        size: Size.infinite,
      ),
    );
  }
}

class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter({required this.spec});

  final PhotoSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Photo frame inside the camera viewport using spec aspect.
    final framePadding = 28.0;
    final maxW = size.width - 2 * framePadding;
    final maxH = size.height - 2 * framePadding;
    double frameW;
    double frameH;
    if (maxW / maxH > spec.aspectRatio) {
      frameH = maxH;
      frameW = frameH * spec.aspectRatio;
    } else {
      frameW = maxW;
      frameH = frameW / spec.aspectRatio;
    }
    final frameLeft = (size.width - frameW) / 2;
    final frameTop = (size.height - frameH) / 2;
    final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);

    // Oval representing the head. Solved with the same rules the processor
    // uses, for a nominally-proportioned head, so the guide cannot ask someone
    // to frame themselves in a way the crop will not reproduce.
    const eyeLineWithinHead = HeadFraming.nominalEyeLineWithinHead;
    final framing = HeadFraming.forSpec(
      spec,
      eyeLineWithinHead: eyeLineWithinHead,
    );
    final ovalH = frameH * framing.faceHeightFraction;
    final ovalW = ovalH * 0.72; // typical head width:height
    final ovalTop =
        frameTop + frameH * framing.crownFraction(eyeLineWithinHead);
    final ovalLeft = frameLeft + (frameW - ovalW) / 2;
    final ovalRect = Rect.fromLTWH(ovalLeft, ovalTop, ovalW, ovalH);

    // Dim everything outside the photo frame.
    final outerPath = Path()..addRect(Offset.zero & size);
    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, outerPath, framePath),
      dim,
    );

    // Frame border.
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      stroke,
    );

    // Face oval guide.
    final ovalStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(ovalRect, ovalStroke);

    // Eye line marker.
    final eyeY = frameTop + frameH * framing.eyeLineFromTopFraction;
    final eyeLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(frameLeft + 12, eyeY),
      Offset(frameLeft + 32, eyeY),
      eyeLine,
    );
    canvas.drawLine(
      Offset(frameLeft + frameW - 32, eyeY),
      Offset(frameLeft + frameW - 12, eyeY),
      eyeLine,
    );

    // Hint label at top.
    final tp = TextPainter(
      text: TextSpan(
        text: 'Align face inside the oval · keep eyes on the line',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: frameW - 16);
    tp.paint(
      canvas,
      Offset(frameLeft + (frameW - tp.width) / 2, frameTop + 12),
    );
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter old) =>
      old.spec.id != spec.id;
}
