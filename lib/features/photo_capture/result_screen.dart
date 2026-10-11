import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_info.dart';
import '../../core/models/photo_spec.dart';
import '../../core/services/review_prompter.dart';
import '../../core/utils/external_links.dart';
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
          // The spec lives in `selectedSpecProvider`, so the camera opens
          // already set up for the same document. Replacing rather than going
          // keeps Home underneath for the back button.
          onRetake: () => context.pushReplacement('/capture'),
          onPickAnother: () => context.go('/'),
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
            spec: spec,
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
          const SizedBox(height: 16),
          _AccessoryRulesCard(spec: spec),
          const SizedBox(height: 24),
          ..._actions(
            allPassed: photo.allPassed,
            unlocked: unlocked,
            price: ref.watch(entitlementProvider.select((s) => s.price)),
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

  /// The buttons under the report, chosen by how the photo did.
  ///
  /// A photo that passed is one worth paying for, so a free user's first
  /// choice is the print-ready file. A photo that failed is not — selling the
  /// upgrade under a red report would be selling a file that will be refused —
  /// so the upsell goes away and the first choice is to fix it. The preview
  /// save stays available either way.
  List<Widget> _actions({
    required bool allPassed,
    required bool unlocked,
    required String? price,
  }) {
    final busy = _exporting;
    final sheetButton = OutlinedButton.icon(
      icon: const Icon(Icons.grid_view_rounded),
      onPressed:
          busy ? null : () => context.push('/sheet', extra: widget.sourcePath),
      label: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('View 4×6" print sheet'),
      ),
    );
    final saveLabel =
        unlocked ? 'Save full-resolution photo' : 'Save watermarked preview';

    if (!allPassed) {
      return [
        FilledButton.icon(
          icon: const Icon(Icons.photo_camera_rounded),
          onPressed: busy ? null : () => context.pushReplacement('/capture'),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Fix and re-shoot'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.save_alt_rounded),
          onPressed: busy ? null : _saveSingle,
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(saveLabel),
          ),
        ),
        const SizedBox(height: 12),
        sheetButton,
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: busy ? null : () => context.go('/'),
          label: const Text('Pick another photo'),
        ),
      ];
    }

    return [
      if (!unlocked) ...[
        _ProUpsell(onTap: _unlockThenSave),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.workspace_premium_rounded),
          onPressed: busy ? null : _unlockThenSave,
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            // The store's own localised price, or none. Never a figure typed
            // here: this string ships to every storefront.
            child: Text(price == null
                ? 'Get the print-ready photo'
                : 'Get the print-ready photo — $price'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.save_alt_rounded),
          onPressed: busy ? null : _saveSingle,
          label: Text(saveLabel),
        ),
        const SizedBox(height: 8),
      ] else ...[
        FilledButton.icon(
          icon: const Icon(Icons.save_alt_rounded),
          onPressed: busy ? null : _saveSingle,
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(saveLabel),
          ),
        ),
        const SizedBox(height: 12),
      ],
      sheetButton,
      const SizedBox(height: 12),
      TextButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: busy ? null : () => context.go('/'),
        label: const Text('Re-shoot or pick another photo'),
      ),
    ];
  }

  /// Opens the paywall and, if the user comes back with the unlock, makes the
  /// save they were reaching for without another tap.
  Future<void> _unlockThenSave() async {
    final bought = await context.push<bool>('/pro');
    if (bought == true && mounted) await _saveSingle();
  }

  Future<void> _saveSingle() async {
    final prompter = ref.read(reviewPrompterProvider);
    setState(() => _exporting = true);
    ExportResult? result;
    try {
      result = await ref.read(exportServiceProvider).savePhoto(widget.photo);
    } catch (e) {
      prompter.suppressSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
    if (result == null || !mounted) return;

    switch (result.outcome) {
      case ExportOutcome.requiresPro:
        await _unlockThenSave();
      case ExportOutcome.failed:
        prompter.suppressSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      case ExportOutcome.saved:
      case ExportOutcome.savedPreview:
        final preview = result.outcome == ExportOutcome.savedPreview;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            // Not under a failed report: see [_actions].
            action: preview && widget.photo.allPassed
                ? SnackBarAction(label: 'Unlock Pro', onPressed: _unlockThenSave)
                : null,
          ),
        );
        unawaited(prompter.onSaveSucceeded(
          fullResolution: !preview,
          allChecksPassed: widget.photo.allPassed,
          isMounted: () => mounted,
        ));
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
    required this.spec,
    required this.checks,
    required this.passColor,
    required this.failColor,
  });

  final PhotoSpec spec;
  final List<ValidationCheck> checks;
  final Color passColor;
  final Color failColor;

  /// One line that says how the photo did. It reports the checks, not the
  /// outcome of an application: no authority has approved anything here
  /// (store_assets/BRAND.md, "never imply official status").
  @visibleForTesting
  static String verdict(PhotoSpec spec, List<ValidationCheck> checks) {
    final failed = checks.where((c) => !c.passed).length;
    if (failed == 0) {
      return 'All ${checks.length} checks passed for '
          '${spec.countryName} ${spec.documentType}';
    }
    return '$failed of ${checks.length} checks '
        '${failed == 1 ? 'needs' : 'need'} attention';
  }

  @override
  Widget build(BuildContext context) {
    final passed = checks.where((c) => c.passed).length;
    // Failures first, so what needs doing is the first thing read. Otherwise
    // the processor's order, which is stable.
    final ordered = [
      ...checks.where((c) => !c.passed),
      ...checks.where((c) => c.passed),
    ];
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
                  verdict(spec, checks),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text('$passed / ${checks.length} passed',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          ...ordered.map((c) => _CheckRow(
                label: c.label,
                detail: c.detail,
                fixHint: c.passed ? null : c.kind.fixHint,
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
    required this.fixHint,
    required this.passed,
    required this.passColor,
    required this.failColor,
  });

  final String label;
  final String detail;
  final String? fixHint;
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
                if (fixHint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'How to fix: $fixHint',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerStatefulWidget {
  const _ErrorView({
    required this.message,
    required this.onRetake,
    required this.onPickAnother,
  });

  final String message;
  final VoidCallback onRetake;
  final VoidCallback onPickAnother;

  @override
  ConsumerState<_ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends ConsumerState<_ErrorView> {
  @override
  void initState() {
    super.initState();
    // A session in which the app could not do its job is not one to ask for
    // a rating in.
    ref.read(reviewPrompterProvider).suppressSession();
  }

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
          Text(widget.message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.onRetake,
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: widget.onPickAnother,
            child: const Text('Pick another photo'),
          ),
        ],
      ),
    );
  }
}

/// The rules this document sets that the app cannot measure.
///
/// Kept visually and verbally apart from the compliance checks above, because
/// the difference matters: those are measurements of this photograph, and
/// these are things only the person in it can confirm. ML Kit's `Face`
/// exposes head angles, eye-open and smiling probabilities, landmarks and
/// contours — nothing about eyewear or headwear — so a glasses "check" could
/// only ever be a guess dressed as a result, on a screen whose entire value is
/// that it shows its working.
///
/// Where the rules have not been read off the issuing authority's own page the
/// card says so rather than filling the gap.
class _AccessoryRulesCard extends StatelessWidget {
  const _AccessoryRulesCard({required this.spec});

  final PhotoSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final verified = spec.accessoryRulesVerified;

    final rows = <(IconData, String)>[
      (
        Icons.visibility_outlined,
        switch (spec.glasses) {
          GlassesRule.notAllowed =>
            'Glasses must be removed for this document.',
          GlassesRule.allowedIfClear =>
            'Glasses are allowed only with clear, untinted lenses, no glare, '
                'and your eyes not covered by the frames.',
          GlassesRule.unverified =>
            'Glasses: this app has not confirmed the rule for this document.',
        }
      ),
      (
        Icons.face_outlined,
        switch (spec.headCovering) {
          HeadCoveringRule.religiousOrMedicalOnly =>
            'Head coverings only for religious or medical reasons, with your '
                'full face visible and no shadow on it.',
          HeadCoveringRule.unverified =>
            'Head coverings: this app has not confirmed the rule for this '
                'document.',
        }
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You have to check these yourself',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'The camera cannot tell whether you are wearing glasses or a head '
            'covering, so these are not part of the checks above.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          if (spec.accessoryNotes != null) ...[
            const SizedBox(height: 8),
            Text(
              spec.accessoryNotes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            verified
                ? 'Read from the issuing authority\'s own guidance. Rules '
                    'change — confirm before you submit.'
                : 'Not confirmed against the issuing authority for this '
                    'document. Check their guidance before you submit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: verified ? scheme.onSurfaceVariant : scheme.error,
            ),
          ),
          if (spec.rulesSource != null) ...[
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              onPressed: () async {
                final ok = await openExternalLink(spec.rulesSource!);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the official guidance.'),
                    ),
                  );
                }
              },
              child: const Text('Read the official guidance'),
            ),
          ],
        ],
      ),
    );
  }
}
