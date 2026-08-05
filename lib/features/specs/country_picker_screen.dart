import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/photo_spec.dart';
import 'specs_repository.dart';

class CountryPickerScreen extends ConsumerStatefulWidget {
  const CountryPickerScreen({super.key});

  @override
  ConsumerState<CountryPickerScreen> createState() => _CountryPickerScreenState();
}

class _CountryPickerScreenState extends ConsumerState<CountryPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final specsAsync = ref.watch(allSpecsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose document'),
      ),
      body: specsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load specs: $e')),
        data: (specs) => _buildList(context, specs),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<PhotoSpec> specs) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? specs
        : specs
            .where((s) =>
                s.countryName.toLowerCase().contains(q) ||
                s.documentType.toLowerCase().contains(q) ||
                s.countryCode.toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search countries or documents',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matches.'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _SpecTile(
                    spec: filtered[i],
                    onTap: () => _select(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _select(PhotoSpec spec) async {
    ref.read(selectedSpecProvider.notifier).state = spec;
    final repo = await ref.read(specsRepositoryProvider.future);
    await repo.saveLastUsedId(spec.id);
    if (!mounted) return;
    context.pop();
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.spec, required this.onTap});

  final PhotoSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Text(
          spec.countryCode,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        ),
      ),
      title: Text(spec.countryName),
      subtitle: Text('${spec.documentType} · ${spec.sizeLabel}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
