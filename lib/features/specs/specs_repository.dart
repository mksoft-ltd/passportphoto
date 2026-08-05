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

  PhotoSpec? findById(String id) =>
      _cache?.firstWhere((s) => s.id == id, orElse: () => _cache!.first);

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
