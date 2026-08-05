import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Renders the free tier's preview export: the same crop the user just made,
/// scaled down past printable resolution and stamped so it cannot pass as a
/// finished document photo.
///
/// Deliberately not reversible. The point is that the free tier proves the
/// crop, the spec and the validation are right — the printable file is what
/// Pro sells.
class Watermarker {
  const Watermarker._();

  // ASCII only: the bundled bitmap font has no glyph for an em dash, and a
  // missing glyph is silently skipped rather than substituted.
  static const String _bandText = 'PREVIEW - Passport Photo Studio';
  static const String _tileText = 'PREVIEW';

  /// Downscale [jpegBytes] so its long edge is [longEdgePx], then stamp it.
  static Uint8List preview(Uint8List jpegBytes, {required int longEdgePx}) {
    final decoded = _tryDecode(jpegBytes);
    if (decoded == null) return jpegBytes;
    return Uint8List.fromList(
      img.encodeJpg(stamp(_downscale(decoded, longEdgePx)), quality: 88),
    );
  }

  /// Stamp an already-sized image, for the on-screen print-sheet preview where
  /// the sheet layout itself is what the user is being shown.
  static Uint8List stampJpeg(Uint8List jpegBytes, {int? longEdgePx}) {
    final decoded = _tryDecode(jpegBytes);
    if (decoded == null) return jpegBytes;
    final sized = longEdgePx == null ? decoded : _downscale(decoded, longEdgePx);
    return Uint8List.fromList(img.encodeJpg(stamp(sized), quality: 88));
  }

  /// `decodeImage` throws — usually a RangeError — on a truncated or empty
  /// file rather than returning null, and both callers above run inside a
  /// background isolate, where an escaped error is hard to attribute to
  /// anything. Both already treat "cannot decode" as "hand the bytes back
  /// untouched", so a throw joins the same path.
  static img.Image? _tryDecode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static img.Image _downscale(img.Image source, int longEdgePx) {
    final long = math.max(source.width, source.height);
    if (long <= longEdgePx) return source;
    final scale = longEdgePx / long;
    return img.copyResize(
      source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  /// Draws the watermark into [image] and returns it.
  ///
  /// Two layers on purpose: a faint tiled repeat that survives a crop, and a
  /// solid bottom band that makes the preview obvious at a glance.
  static img.Image stamp(img.Image image) {
    final font = img.arial24;
    final tileWidth = _textWidth(font, _tileText);
    final int stepX = tileWidth + math.max(48, image.width ~/ 6);
    final int stepY = math.max(56, image.height ~/ 7);

    var row = 0;
    for (var y = -stepY; y < image.height; y += stepY, row++) {
      // Stagger alternate rows so the repeat reads as a pattern rather than
      // as columns that could be cropped between.
      final offset = (row.isEven ? 0 : stepX ~/ 2) - stepX ~/ 3;
      for (var x = offset; x < image.width; x += stepX) {
        img.drawString(
          image,
          _tileText,
          font: font,
          x: x,
          y: y,
          color: img.ColorRgba8(20, 24, 32, 58),
        );
      }
    }

    final int bandHeight = math.max(30, (image.height * 0.09).round());
    final bandTop = image.height - bandHeight;
    img.fillRect(
      image,
      x1: 0,
      y1: bandTop,
      x2: image.width - 1,
      y2: image.height - 1,
      color: img.ColorRgba8(12, 16, 22, 176),
    );

    final bandTextWidth = _textWidth(font, _bandText);
    img.drawString(
      image,
      _bandText,
      font: font,
      x: math.max(4, (image.width - bandTextWidth) ~/ 2),
      y: bandTop + math.max(2, (bandHeight - 24) ~/ 2),
      color: img.ColorRgba8(255, 255, 255, 235),
    );

    return image;
  }

  static int _textWidth(img.BitmapFont font, String text) {
    var width = 0;
    for (final code in text.codeUnits) {
      final ch = font.characters[code];
      if (ch != null) width += ch.xAdvance;
    }
    return width;
  }
}
