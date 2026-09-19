import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/photo_spec.dart';
import '../../core/services/preferences.dart';

class SpecsRepository {
  SpecsRepository(this._prefs);

  static const String _assetPath = 'assets/specs/photo_specs.json';
  static const String _lastUsedKey = 'last_used_spec_id';

  final SharedPreferences _prefs;
  List<PhotoSpec>? _cache;

  Future<List<PhotoSpec>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['specs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PhotoSpec.fromJson)
        .toList();
    list.sort((a, b) {
      final c = a.countryName.compareTo(b.countryName);
      if (c != 0) return c;
      return a.documentType.compareTo(b.documentType);
    });
    _cache = list;
    return list;
  }

  /// The spec with this id, or null when there is no such spec.
  ///
  /// Null, not a substitute. This used to fall back to `_cache!.first` — the
  /// alphabetically first country — so an id that no longer exists, which is
  /// exactly what a saved `last_used_spec_id` becomes when a spec is renamed
  /// in an update, would silently crop the user's photo to a different
  /// country's document and say nothing. (It also threw on an empty cache.)
  /// Callers pick the fallback themselves; `HomeScreen` already does.
  PhotoSpec? findById(String id) {
    for (final spec in _cache ?? const <PhotoSpec>[]) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  Future<String?> readLastUsedId() async => _prefs.getString(_lastUsedKey);

  Future<void> saveLastUsedId(String id) async {
    await _prefs.setString(_lastUsedKey, id);
  }
}

final specsRepositoryProvider = FutureProvider<SpecsRepository>((ref) async {
  final repo = SpecsRepository(ref.watch(sharedPreferencesProvider));
  await repo.loadAll();
  return repo;
});

final allSpecsProvider = FutureProvider<List<PhotoSpec>>((ref) async {
  final repo = await ref.watch(specsRepositoryProvider.future);
  return repo.loadAll();
});

/// Currently-selected spec. Initially seeded from last-used or the ICAO generic.
final selectedSpecProvider = StateProvider<PhotoSpec?>((ref) => null);
