import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../processing/processed_photo.dart';
import '../processing/processing_providers.dart';
import '../purchase/entitlement_controller.dart';
import 'export_service.dart';

/// Renders the 4×6" sheet the user would take to a print shop.
///
/// Free users see the real layout, watermarked — hiding it entirely would make
/// the upsell abstract, and the whole point of this app is that you can tell
/// whether it worked before you pay.
@visibleForTesting
final sheetPreviewProvider = FutureProvider.family
    .autoDispose<Uint8List, String>((ref, sourcePath) async {
  // Watched, not read. `exportServiceProvider` deliberately does not depend on
  // the entitlement — it looks the flag up at the moment of export — so
  // nothing else here changes when a purchase completes. Without this line a
  // user who bought Pro from this very screen (the locked save button pushes
  // `/pro`) came back to a sheet still stamped PREVIEW, under a button that
  // now read "Save print sheet to gallery". The saved file was correct; only
  // the picture of it was stale, which is the one thing this screen exists to
  // show honestly.
  ref.watch(isProUnlockedProvider);
  final photo = await ref.watch(processedPhotoProvider(sourcePath).future);
  return ref.watch(exportServiceProvider).buildSheetPreview(photo);
});

class PrintSheetScreen extends ConsumerWidget {
  const PrintSheetScreen({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(sheetPreviewProvider(sourcePath));
    final photo = ref.watch(processedPhotoProvider(sourcePath));

    return Scaffold(
      appBar: AppBar(title: const Text('4×6" print sheet')),
      body: preview.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Laying out the sheet…'),
            ],
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Could not build the sheet: $e')),
        ),
        data: (bytes) => _SheetView(
          bytes: bytes,
          photo: photo.valueOrNull,
        ),
      ),
    );
  }
}

class _SheetView extends ConsumerStatefulWidget {
  const _SheetView({required this.bytes, required this.photo});

  final Uint8List bytes;
  final ProcessedPhoto? photo;

  @override
  ConsumerState<_SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends ConsumerState<_SheetView> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(isProUnlockedProvider);
    final photo = widget.photo;
    final copies = _copiesOnSheet(photo);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copies == null
                ? 'A standard 6×4 inch photo print at 300 dpi.'
                : '$copies copies at exactly ${photo!.spec.sizeLabel.split(' @').first}, '
                    'on a standard 6×4 inch print at 300 dpi. Cut along the gaps.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: Icon(unlocked ? Icons.save_alt_rounded : Icons.lock_outline_rounded),
            onPressed: _saving || photo == null ? null : () => _save(photo),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(unlocked
                  ? 'Save print sheet to gallery'
                  : 'Unlock Pro to save this sheet'),
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  int? _copiesOnSheet(ProcessedPhoto? photo) {
    if (photo == null) return null;
    const sheetDpi = 300;
    const margin = 30;
    const gap = 20;
    final tileW = (photo.spec.widthMm / 25.4 * sheetDpi).round();
    final tileH = (photo.spec.heightMm / 25.4 * sheetDpi).round();
    final cols = (6 * sheetDpi - 2 * margin + gap) ~/ (tileW + gap);
    final rows = (4 * sheetDpi - 2 * margin + gap) ~/ (tileH + gap);
    final total = cols * rows;
    return total > 0 ? total : null;
  }

  Future<void> _save(ProcessedPhoto photo) async {
    setState(() => _saving = true);
    try {
      final result = await ref.read(exportServiceProvider).savePrintSheet(photo);
      if (!mounted) return;
      if (result.outcome == ExportOutcome.requiresPro) {
        context.push('/pro');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
