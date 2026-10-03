import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/database/json_store.dart';
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

  /// 记录条数上限。超出后丢弃最旧的记录（文件不动——用户的文件不该被
  /// 一个"记录上限"悄悄删掉；孤儿文件由用户自己或系统清理决定）。
  static const int maxEntries = 500;

  static JsonListStore get _store => JsonListStore(HiveSetup.settingsBox, _key);

  List<DownloadEntry> getAll() => _store
      .read()
      .map((m) {
        try {
          return DownloadEntry.fromJson(m);
        } catch (_) {
          return null;
        }
      })
      .whereType<DownloadEntry>()
      .toList();

  /// 新增一条下载记录。
  ///
  /// 按 (serverId, postId) 去重：同一帖重复下载此前会堆积多条记录，而文件名
  /// 相同、互相覆盖，结果是"同一张图好几条记录，路径都一样"。
  Future<void> add(DownloadEntry entry) {
    return _store.update((items) {
      final key = _dedupeKey(entry.serverId, entry.postId);
      final next = items
          .where((m) =>
              _dedupeKey('${m['serverId'] ?? ''}', '${m['postId'] ?? ''}') != key)
          .toList();
      next.insert(0, entry.toJson());
      if (next.length > maxEntries) {
        next.removeRange(maxEntries, next.length);
      }
      return next;
    });
  }

  /// 按 postId + serverId 精确定位删除。传入 serverId 时只删该站点的记录，
  /// 避免不同站点的同名 post 互相误删；传 null 则删除所有站点下该 id。
  Future<void> remove(String postId, {String? serverId}) {
    return _store.update((items) {
      return items.where((m) {
        if ('${m['postId'] ?? ''}' != postId) return true;
        if (serverId == null) return false;
        return '${m['serverId'] ?? ''}' != serverId;
      }).toList();
    });
  }

  Future<void> clear() => _store.clear();

  Future<void> saveAll(List<DownloadEntry> entries) {
    return _store.write(entries.map((e) => e.toJson()).toList());
  }

  int get count => getAll().length;

  static String _dedupeKey(String serverId, String postId) =>
      '$serverId|$postId';
}
