import 'dart:convert';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/json_safe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userDownloadsRepoProvider = Provider<UserDownloadsRepo>((ref) {
  return UserDownloadsRepo();
});

class DownloadEntry {
  const DownloadEntry({
    required this.postId,
    required this.imageUrl,
    required this.localPath,
    required this.downloadedAt,
    this.width,
    this.height,
    this.serverId = '',
  });

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
        postId: json['postId'] as String,
        imageUrl: json['imageUrl'] as String,
        localPath: json['localPath'] as String,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        width: json['width'] as int?,
        height: json['height'] as int?,
        serverId: json['serverId']?.toString() ?? '',
      );

  final String postId;
  final String imageUrl;
  final String localPath;
  final DateTime downloadedAt;
  final int? width;
  final int? height;

  /// 所属站点。postId 在不同站点会重复，仅按 postId 删除会误伤同名条目。
  final String serverId;

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'imageUrl': imageUrl,
        'localPath': localPath,
        'downloadedAt': downloadedAt.toIso8601String(),
        'width': width,
        'height': height,
        'serverId': serverId,
      };
}

class UserDownloadsRepo {
  static const _key = 'downloads';
  static Future<void> _writeQueue = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.catchError((_) {});
    return result;
  }

  List<DownloadEntry> getAll() {
    final raw = asStringOrNull(HiveSetup.settingsBox.get(_key));
    final list = decodeJsonList(raw);
    // 逐条容错：单条畸形数据跳过，不让整个列表崩溃。
    return list
        .map((e) {
          final m = asStringMap(e);
          if (m == null) return null;
          try {
            return DownloadEntry.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<DownloadEntry>()
        .toList();
  }

  Future<void> add(DownloadEntry entry) {
    return _enqueue(() async {
      final all = getAll();
      all.insert(0, entry);
      if (all.length > 500) all.removeRange(500, all.length);
      await _save(all);
    });
  }

  /// 按 postId + serverId 精确定位删除。传入 serverId 时只删该站点的记录，
  /// 避免不同站点的同名 post 互相误删。
  Future<void> remove(String postId, {String? serverId}) {
    return _enqueue(() async {
      final all = getAll();
      if (serverId == null) {
        all.removeWhere((e) => e.postId == postId);
      } else {
        all.removeWhere((e) => e.postId == postId && e.serverId == serverId);
      }
      await _save(all);
    });
  }

  Future<void> clear() {
    return _enqueue(() => HiveSetup.settingsBox.delete(_key));
  }

  Future<void> saveAll(List<DownloadEntry> entries) {
    return _enqueue(() async {
      final json = entries.map((e) => e.toJson()).toList();
      await HiveSetup.settingsBox.put(_key, jsonEncode(json));
    });
  }

  int get count => getAll().length;

  Future<void> _save(List<DownloadEntry> entries) async {
    final json = entries.map((e) => e.toJson()).toList();
    await HiveSetup.settingsBox.put(_key, jsonEncode(json));
  }
}
