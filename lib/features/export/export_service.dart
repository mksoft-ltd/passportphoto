import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../../core/constants/app_info.dart';
import '../processing/photo_processor.dart';
import '../processing/processed_photo.dart';
import '../processing/processing_providers.dart';
import '../purchase/entitlement_controller.dart';
import 'watermark.dart';

enum ExportOutcome {
  /// Full-resolution, unwatermarked file written to the gallery.
  saved,

  /// Free tier: a downscaled, watermarked copy went to the gallery.
  savedPreview,

  /// Pro-only export attempted without the unlock.
  requiresPro,

  /// The gallery write itself failed.
  failed,
}

class ExportResult {
  const ExportResult({required this.outcome, required this.message});

  final ExportOutcome outcome;
  final String message;
}

/// Owns everything that leaves the app: the gallery writes and the Pro gate in
/// front of them.
///
/// The entitlement is read here, through [_isUnlocked], rather than passed in
/// by the screen. A caller that forgets the check — or gets it wrong — cannot
/// therefore hand out a printable file for free.
class ExportService {
  ExportService(this._processor, this._isUnlocked);

  final PhotoProcessor _processor;
  final bool Function() _isUnlocked;

  /// Saves the cropped photo. Pro gets the full-resolution file; everyone else
  /// gets a watermarked preview so they can see the crop and the spec were
  /// applied correctly before deciding to buy.
  Future<ExportResult> savePhoto(ProcessedPhoto photo) async {
    final unlocked = _isUnlocked();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    final Uint8List bytes;
    final String filename;
    if (unlocked) {
      bytes = photo.jpegBytes;
      filename = 'passport_${photo.spec.id}_$stamp.jpg';
    } else {
      final source = photo.jpegBytes;
      bytes = await Isolate.run(
        () => Watermarker.preview(source, longEdgePx: AppInfo.previewLongEdgePx),
      );
      filename = 'passport_preview_${photo.spec.id}_$stamp.jpg';
    }

    return _save(
      bytes,
      filename: filename,
      successOutcome:
          unlocked ? ExportOutcome.saved : ExportOutcome.savedPreview,
      successMessage: unlocked
          ? 'Full-resolution photo saved to your gallery.'
          : 'Watermarked preview saved. Unlock Pro for the print-ready file.',
    );
  }

  /// Saves the 4×6" print sheet. Pro only — the sheet is the thing people take
  /// to a print shop, so it is the paid artefact.
  Future<ExportResult> savePrintSheet(ProcessedPhoto photo) async {
    if (!_isUnlocked()) {
      return const ExportResult(
        outcome: ExportOutcome.requiresPro,
        message: 'The 4×6" print sheet is part of Passport Photo Studio Pro.',
      );
    }

    final bytes = await _processor.buildPrintSheet(photo);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return _save(
      bytes,
      filename: 'passport_sheet_${photo.spec.id}_$stamp.jpg',
      successOutcome: ExportOutcome.saved,
      successMessage: 'Print sheet saved to your gallery.',
    );
  }

  /// Renders the print sheet for on-screen preview. Free users can see exactly
  /// what they would be buying; the bytes are watermarked so a screenshot is
  /// not a usable substitute for the export.
  Future<Uint8List> buildSheetPreview(ProcessedPhoto photo) async {
    final sheet = await _processor.buildPrintSheet(photo);
    if (_isUnlocked()) return sheet;
    return Isolate.run(() => Watermarker.stampJpeg(sheet, longEdgePx: 1000));
  }

  /// The gallery write is the only thing that produces a file.
  ///
  /// Until 2026-08-05 this also wrote a second, full copy of every export into
  /// the temp directory, returned as `ExportResult.filePath` for a share sheet
  /// that was never built — so nothing read it and nothing deleted it. For a
  /// Pro user that copy was the full-resolution, unwatermarked, print-ready
  /// passport photo, accumulating in the app container forever while
  /// `PRIVACY_POLICY.md` said the only copies that persist are the ones the
  /// user deliberately saved. If a share sheet does arrive later, write the
  /// temp file at that point and delete it when the share completes.
  Future<ExportResult> _save(
    Uint8List bytes, {
    required String filename,
    required ExportOutcome successOutcome,
    required String successMessage,
  }) async {
    final result = await SaverGallery.saveImage(
      bytes,
      fileName: filename,
      androidRelativePath: 'Pictures/PassportPhotoStudio',
      skipIfExists: false,
    );

    if (!result.isSuccess) {
      return ExportResult(
        outcome: ExportOutcome.failed,
        message: result.errorMessage ?? 'Could not save to your gallery.',
      );
    }
    return ExportResult(outcome: successOutcome, message: successMessage);
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  // Read, not watch: the flag is looked up at the moment of export, so a
  // purchase completed on the results screen takes effect without the service
  // being rebuilt underneath an in-flight save.
  return ExportService(
    ref.watch(photoProcessorProvider),
    () => ref.read(isProUnlockedProvider),
  );
});
