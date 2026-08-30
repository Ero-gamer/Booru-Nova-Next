import 'dart:convert';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchHistoryRepoProvider = Provider<SearchHistoryRepo>((ref) {
  return SearchHistoryRepo();
});

class SearchHistoryRepo {
  static const _key = 'search_history';

  List<String> getAll() {
    final raw = asStringOrNull(HiveSetup.settingsBox.get(_key));
    // 跳过非字符串元素，避免单条脏数据让整个列表 load 崩溃。
    return decodeJsonList(raw).whereType<String>().toList();
  }

  Future<void> add(String query) async {
    final all = getAll();
    all.remove(query);
    all.insert(0, query);
    if (all.length > 20) all.removeRange(20, all.length);
    await HiveSetup.settingsBox.put(_key, jsonEncode(all));
  }

  Future<void> remove(String query) async {
    final all = getAll();
    all.remove(query);
    await HiveSetup.settingsBox.put(_key, jsonEncode(all));
  }

  Future<void> clear() async {
    await HiveSetup.settingsBox.delete(_key);
  }

  Future<void> replaceAll(List<String> items) async {
    await HiveSetup.settingsBox.put(_key, jsonEncode(items.take(20).toList()));
  }
}
