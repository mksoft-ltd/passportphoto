import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_info.dart';
import '../../core/models/photo_spec.dart';
import '../export/export_service.dart';
import '../processing/photo_processor.dart';
import '../processing/processed_photo.dart';
import '../processing/processing_providers.dart';
import '../purchase/entitlement_controller.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPhoto = ref.watch(processedPhotoProvider(sourcePath));

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: asyncPhoto.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Detecting face & cropping…'),
            ],
          ),
        ),
        error: (e, _) => _ErrorView(
          message: e is PhotoProcessingFailure ? e.message : e.toString(),
          onRetake: () => context.go('/'),
        ),
        data: (photo) => _ResultView(photo: photo, sourcePath: sourcePath),
      ),
    );
  }
}

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.photo, required this.sourcePath});

  final ProcessedPhoto photo;
  final String sourcePath;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final spec = photo.spec;
    final unlocked = ref.watch(isProUnlockedProvider);
    final passColor = Theme.of(context).semantics.pass;
    final failColor = Theme.of(context).colorScheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _PhotoPreview(photo: photo, unlocked: unlocked)),
          const SizedBox(height: 20),
          Text(spec.displayLabel,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${photo.widthPx} × ${photo.heightPx} px · ${spec.sizeLabel} · '
            'Background: ${spec.background.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!unlocked) ...[
            const SizedBox(height: 4),
            Text(
              'Preview — Pro exports at full print resolution.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          _ChecklistCard(
            checks: photo.checks,
            passColor: passColor,
            failColor: failColor,
          ),
          if (spec.notes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(spec.notes!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!unlocked) ...[
            _ProUpsell(onTap: () => context.push('/pro')),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: _exporting ? null : _saveSingle,
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(unlocked
                  ? 'Save full-resolution photo'
                  : 'Save watermarked preview'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: _exporting
                ? null
                : () => context.push('/sheet', extra: widget.sourcePath),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('View 4×6" print sheet'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _exporting ? null : () => context.go('/'),
            label: const Text('Re-shoot or pick another photo'),
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _saveSingle() async {
    setState(() => _exporting = true);
    try {
      final result =
          await ref.read(exportServiceProvider).savePhoto(widget.photo);
      if (!mounted) return;
      if (result.outcome == ExportOutcome.requiresPro) {
        context.push('/pro');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          action: result.outcome == ExportOutcome.savedPreview
              ? SnackBarAction(
                  label: 'Unlock Pro',
                  onPressed: () => context.push('/pro'),
                )
              : null,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

/// The finished crop, on the spec's own background.
///
/// A locked user is shown at most [AppInfo.lockedPreviewLongEdgePx] of real
/// detail: the bytes are decoded at that size and the layout scales the result
/// up to fill the same box, so the crop, the framing and the background are all
/// still legible while a screenshot of this screen is no longer a substitute
/// for the export. Pro decodes the bytes as they are.
///
/// The cap is on the decode rather than on the bytes because the decode is what
/// reaches the screen, and the screen is the whole of the exposure — the bytes
/// were always in this process's memory and reading them out of it needs a
/// compromised device, which already defeats the local Pro flag anyway.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, required this.unlocked});

  final ProcessedPhoto photo;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final spec = photo.spec;
    final capped = !unlocked &&
        math.max(photo.widthPx, photo.heightPx) >
            AppInfo.lockedPreviewLongEdgePx;
    // Cap the long edge only, so the other edge follows from the aspect ratio
    // instead of being stretched to meet a second constraint.
    final portrait = photo.heightPx >= photo.widthPx;

    return Container(
      decoration: BoxDecoration(
        color: spec.background.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: spec.aspectRatio,
          child: Image.memory(
            photo.jpegBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth:
                capped && !portrait ? AppInfo.lockedPreviewLongEdgePx : null,
            cacheHeight:
                capped && portrait ? AppInfo.lockedPreviewLongEdgePx : null,
          ),
        ),
      ),
    );
  }
}

/// Sits above the export buttons only while the app is unlicensed, and says
/// exactly what the paid version adds. Nothing here blocks the free flow —
/// the crop, the spec and the compliance report are already done by the time
/// this is on screen.
class _ProUpsell extends StatelessWidget {
  const _ProUpsell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free saves are watermarked',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pro unlocks the full-resolution file and the 4×6" print '
                      'sheet, once.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.checks,
    required this.passColor,
    required this.failColor,
  });

  final List<ValidationCheck> checks;
  final Color passColor;
  final Color failColor;

  @override
  Widget build(BuildContext context) {
    final passed = checks.where((c) => c.passed).length;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compliance checks',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text('$passed / ${checks.length} passed',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          ...checks.map((c) => _CheckRow(
                label: c.label,
                detail: c.detail,
                passed: c.passed,
                passColor: passColor,
                failColor: failColor,
              )),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.detail,
    required this.passed,
    required this.passColor,
    required this.failColor,
  });

  final String label;
  final String detail;
  final bool passed;
  final Color passColor;
  final Color failColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.error_rounded,
            color: passed ? passColor : failColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetake});

  final String message;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Could not process photo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetake, child: const Text('Try again')),
        ],
      ),
    );
  }
}
