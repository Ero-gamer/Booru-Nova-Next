import 'dart:convert';

import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final userServerRepoProvider = Provider<UserServerRepo>((ref) {
  return UserServerRepo();
});

class UserServerRepo {
  Box get _box => HiveSetup.serversBox;
  Box get _settingsBox => HiveSetup.settingsBox;
  static const _orderKey = 'server_order';

  List<String> get _order {
    final raw = _settingsBox.get(_orderKey);
    if (raw is! List) return [];
    // 跳过非字符串元素，避免 schema 漂移时 cast 抛错。
    return raw.whereType<String>().toList();
  }

  Future<void> _saveOrder(List<String> order) async {
    await _settingsBox.put(_orderKey, order);
  }

  List<BooruServer> getAll() {
    final servers = <BooruServer>[];
    for (final v in _box.values) {
      if (v is! String) continue;
      try {
        final map = asStringMap(jsonDecode(v));
        if (map == null) continue;
        servers.add(BooruServer.fromJson(map));
      } catch (_) {
        // 单条数据损坏时跳过，不让整个服务器列表加载崩溃。
      }
    }

    final order = _order;
    if (order.isEmpty) return servers;

    final map = {for (final s in servers) s.id: s};
    final ordered = <BooruServer>[];
    for (final id in order) {
      if (map.containsKey(id)) {
        ordered.add(map.remove(id)!);
      }
    }
    ordered.addAll(map.values);
    return ordered;
  }

  Future<void> reorder(int oldIndex, int newIndex) {
    final order = _order;
    if (order.isEmpty) {
      final all = _box.keys.cast<String>().toList();
      if (newIndex > oldIndex) newIndex--;
      final item = all.removeAt(oldIndex);
      all.insert(newIndex, item);
      return _saveOrder(all);
    }
    if (newIndex > oldIndex) newIndex--;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    return _saveOrder(order);
  }

  BooruServer? getById(String id) {
    final raw = _box.get(id);
    if (raw is! String) return null;
    try {
      final map = asStringMap(jsonDecode(raw));
      if (map == null) return null;
      return BooruServer.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BooruServer server) async {
    await _box.put(server.id, jsonEncode(server.toJson()));
    final order = _order;
    if (!order.contains(server.id)) {
      order.add(server.id);
      await _saveOrder(order);
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    final order = _order;
    order.remove(id);
    await _saveOrder(order);
  }

  Future<void> update(BooruServer server) async {
    await save(server);
  }

  int get count => _box.length;
}
