import 'dart:convert';

import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final userHostsRepoProvider = Provider<UserHostsRepo>((ref) {
  return UserHostsRepo();
});

class UserHostsRepo {
  Box get _box => HiveSetup.settingsBox;
  static const _key = 'hosts';

  List<HostEntry> getAll() {
    final raw = _box.get(_key) as String?;
    final list = decodeJsonList(raw);
    return list.map((e) {
      final m = asStringMap(e);
      if (m == null) return null;
      try {
        return HostEntry.fromJson(m);
      } catch (_) {
        return null;
      }
    }).whereType<HostEntry>().toList();
  }

  HostEntry? getByDomain(String domain) {
    final lower = domain.toLowerCase();
    return getAll().where((h) => h.domain.toLowerCase() == lower).firstOrNull;
  }

  HostEntry? match(String urlDomain) {
    final lower = urlDomain.toLowerCase();
    return getAll()
        .where((h) => lower.contains(h.domain.toLowerCase()))
        .firstOrNull;
  }

  Future<void> add(HostEntry entry) async {
    final all = getAll();
    all.removeWhere((h) => h.domain.toLowerCase() == entry.domain.toLowerCase());
    all.add(entry);
    await _persist(all);
  }

  Future<void> remove(String domain) async {
    final all = getAll();
    all.removeWhere((h) => h.domain.toLowerCase() == domain.toLowerCase());
    await _persist(all);
  }

  Future<void> update(HostEntry entry) async {
    await add(entry);
  }

  Future<void> replaceAll(List<HostEntry> entries) {
    return _persist(entries);
  }

  Future<void> clear() async {
    await _persist([]);
  }

  Future<void> _persist(List<HostEntry> entries) async {
    await _box.put(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}
