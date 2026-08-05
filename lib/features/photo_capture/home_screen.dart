import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_info.dart';
import '../../core/demo/demo_data.dart';
import '../../core/models/photo_spec.dart';
import '../purchase/entitlement_controller.dart';
import '../specs/specs_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    // First-time seed of selected spec from prefs / default to ICAO generic.
    ref.listen(specsRepositoryProvider, (prev, next) {
      next.whenData((repo) async {
        if (_seeded || ref.read(selectedSpecProvider) != null) return;
        _seeded = true;
        final id = AppInfo.screenshotMode
            ? DemoData.specId
            : await repo.readLastUsedId();
        final all = await repo.loadAll();
        final spec = (id != null
                ? all.where((s) => s.id == id).cast<PhotoSpec?>().firstOrNull
                : null) ??
            all.firstWhere((s) => s.id == 'icao_generic', orElse: () => all.first);
        ref.read(selectedSpecProvider.notifier).state = spec;
      });
    });

    final spec = ref.watch(selectedSpecProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport Photo Studio'),
        actions: [
          // Always present, unlocked or not: this is also where "Restore
          // purchase" lives, which both stores require to be reachable.
          IconButton(
            icon: Icon(
              ref.watch(isProUnlockedProvider)
                  ? Icons.workspace_premium_rounded
                  : Icons.workspace_premium_outlined,
            ),
            tooltip: 'Passport Photo Studio Pro',
            onPressed: () => context.push('/pro'),
          ),
        ],
      ),
      // The footer is pushed to the bottom by a Spacer on a roomy screen, but
      // a Spacer needs a bounded height and this column does not fit a small
      // phone or any landscape window. Scrolling with a minimum height as tall
      // as the viewport keeps both: the layout stays anchored where there is
      // room, and scrolls instead of overflowing where there is not.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 32),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Document',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    _SpecCard(
                      spec: spec,
                      onTap: () => context.push('/picker'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Source photo',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.camera_alt_rounded,
                      title: 'Take a new photo',
                      subtitle: 'Use the camera with a face guide overlay',
                      enabled: spec != null,
                      onTap: () => context.push('/capture'),
                    ),
                    const SizedBox(height: 12),
                    _ActionTile(
                      icon: Icons.image_rounded,
                      title: 'Pick from gallery',
                      subtitle: 'Select an existing selfie or headshot',
                      enabled: spec != null,
                      onTap: () => _pickFromGallery(context),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    Text(
                      'All processing happens on your device. '
                      'No photos leave your phone.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) return;
    if (!context.mounted) return;
    context.push('/result', extra: file.path);
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.spec, required this.onTap});

  final PhotoSpec? spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  spec?.countryCode ?? '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec?.displayLabel ?? 'Choose a country & document',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec?.sizeLabel ?? 'Tap to select',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: enabled
          ? theme.colorScheme.surfaceContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
