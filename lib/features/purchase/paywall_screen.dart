import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/utils/external_links.dart';
import 'entitlement_controller.dart';

/// One honest offer: a single payment, restorable, and the app stays fully
/// usable for anyone who closes this screen.
///
/// No countdown, no struck-through "was" price, nothing pre-ticked, and every
/// country and validation check stays free — what Pro buys is the printable
/// file, not access to the tool.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider);

    // A purchase that is declined or abandoned resolves on the store's stream,
    // long after the tap that started it returned, so the message has to reach
    // the user this way rather than as a return value.
    ref.listen(entitlementProvider.select((s) => s.errorMessage), (_, message) {
      if (message == null) return;
      _notify(context, message);
      ref.read(entitlementProvider.notifier).acknowledgeError();
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Passport Photo Studio Pro'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _Hero(),
            const SizedBox(height: 24),
            if (entitlement.unlocked)
              const _AlreadyUnlocked()
            else ...[
              const _ComparisonTable(),
              const SizedBox(height: 20),
              const _Reassurance(),
              const SizedBox(height: 24),
              _BuyButton(entitlement: entitlement),
              const SizedBox(height: 4),
              _RestoreButton(entitlement: entitlement),
              const SizedBox(height: 12),
              const _SmallPrint(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primaryContainer,
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            size: 36,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Print-ready photos,\nfor one payment',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(height: 1.25, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          // No currency figure here on purpose: this screen ships to every
          // storefront in one English string, so a "£6" quoted to a US or
          // eurozone user is both wrong and a price claim about someone else's
          // business. Same reasoning as store screenshot 02
          // (store_assets/screenshot_specs.md).
          'A photo booth charges several times more for a single set. Pro is '
          'a one-time unlock and you can shoot as many as you like.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// The free-vs-Pro split, stated plainly. Every country and every compliance
/// check sits in the free column on purpose — the app has to be genuinely
/// useful before it asks for money.
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const _rows = <(String, bool)>[
    ('All 30 document specs, 21 countries', false),
    ('Camera guide and automatic face crop', false),
    ('Full compliance report', false),
    ('Watermarked preview you can save', false),
    ('Full-resolution photo, no watermark', true),
    ('4×6" print sheet for photo shops', true),
    ('Saved straight to your gallery', true),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 52,
                child: Text(
                  'Free',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  'Pro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          for (final (label, proOnly) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Icon(
                      proOnly ? Icons.remove_rounded : Icons.check_rounded,
                      size: 20,
                      color: proOnly
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                          : scheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Reassurance extends StatelessWidget {
  const _Reassurance();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paid once, yours for good',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'No subscription, no ads, no account. Your photos are never '
                  'uploaded anywhere — everything happens on this device.',
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

class _BuyButton extends ConsumerWidget {
  const _BuyButton({required this.entitlement});

  final EntitlementState entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton(
      onPressed: entitlement.busy
          ? null
          : () => ref.read(entitlementProvider.notifier).purchase(),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      child: entitlement.busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          // No price means the store has not answered yet. "Unlock Pro" on its
          // own is the honest label — the alternative is printing a figure and
          // a currency this user may never be charged, which Play rejects.
          : Text(
              entitlement.price == null
                  ? 'Unlock Pro'
                  : 'Unlock Pro — ${entitlement.price}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton({required this.entitlement});

  final EntitlementState entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: entitlement.busy
          ? null
          : () async {
              final message =
                  await ref.read(entitlementProvider.notifier).restore();
              if (!context.mounted) return;
              _notify(context, message ?? 'Your purchase has been restored.');
            },
      child: const Text('Restore purchase'),
    );
  }
}

class _AlreadyUnlocked extends StatelessWidget {
  const _AlreadyUnlocked();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, size: 36, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Pro is active',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Full-resolution exports and the 4×6" print sheet are unlocked on '
            'this device. Thank you for buying it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SmallPrint extends StatelessWidget {
  const _SmallPrint();

  @override
  Widget build(BuildContext context) {
    final store = !kIsWeb && Platform.isIOS ? 'App Store' : 'Google Play';
    return Column(
      children: [
        Text(
          'A one-time purchase billed through your $store account. There is no '
          'subscription to cancel, and Passport Photo Studio stays fully '
          'usable without it.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () async {
            final ok = await openExternalLink(AppInfo.privacyPolicyUrl);
            if (!ok && context.mounted) {
              _notify(context, 'Could not open the privacy policy.');
            }
          },
          child: const Text('Privacy policy'),
        ),
      ],
    );
  }
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
