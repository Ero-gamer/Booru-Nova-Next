import 'dart:async';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:gal/gal.dart';

/// 单文件批处理并发上限：避免同一时间打爆网络 / 图库写入。
const int _maxConcurrency = 3;

class BatchOps {
  BatchOps._();

  /// 批量下载并写入图库。
  ///
  /// [downloadPath] 为用户设置的下载目录（空则回退临时目录）。
  /// 本地文件名以 postId 为前缀保证唯一，避免同名覆盖。
  /// 并发控制在 [_maxConcurrency]，[onItemProgress] 可选回调输出逐项进度。
  static Future<BatchDownloadResult> downloadAll(
    List<String> urls,
    List<String> postIds, {
    String downloadPath = '',
    void Function(int done, int total)? onItemProgress,
  }) async {
    final results = <BatchItem?>[];
    results.length = urls.length;

    final dir = await resolveDownloadDir(downloadPath);
    var done = 0;

    Future<void> runOne(int i) async {
      final id = i < postIds.length ? postIds[i] : null;
      final item = await _downloadOne(urls[i], id, dir.path);
      results[i] = item;
      done += 1;
      onItemProgress?.call(done, urls.length);
    }

    // 分块并发：每批最多 _maxConcurrency 个，批次内 Future.wait。
    for (var start = 0; start < urls.length; start += _maxConcurrency) {
      final end = (start + _maxConcurrency) < urls.length
          ? start + _maxConcurrency
          : urls.length;
      final batch = <Future<void>>[
        for (var i = start; i < end; i++) runOne(i),
      ];
      await Future.wait(batch, eagerError: false);
    }

    final nonNull = results.whereType<BatchItem>().toList();
    return BatchDownloadResult(
      items: nonNull,
      successCount: nonNull.where((r) => r.success).length,
      failCount: nonNull.where((r) => !r.success).length,
    );
  }

  static Future<BatchItem> _downloadOne(
      String url, String? postId, String dirPath) async {
    try {
      if (!url.split('/').last.contains('.')) {
        return BatchItem(url: url, success: false, error: 'No file extension');
      }

      final path = '$dirPath/$uniqueFileName(url, postId: postId)';
      final dio = DioFactory.createDownload();
      await dio.download(url, path);
      await Gal.putImage(path);

      if (postId != null && postId.isNotEmpty) {
        final repo = UserDownloadsRepo();
        await repo.add(DownloadEntry(
          postId: postId,
          imageUrl: url,
          localPath: path,
          downloadedAt: DateTime.now(),
        ));
      }

      return BatchItem(url: url, success: true);
    } catch (e) {
      return BatchItem(url: url, success: false, error: e.toString());
    }
  }
}

class BatchDownloadResult {
  const BatchDownloadResult({
    required this.items,
    required this.successCount,
    required this.failCount,
  });

  final List<BatchItem> items;
  final int successCount;
  final int failCount;
}

class BatchItem {
  const BatchItem({
    required this.url,
    required this.success,
    this.error,
  });

  final String url;
  final bool success;
  final String? error;
}
