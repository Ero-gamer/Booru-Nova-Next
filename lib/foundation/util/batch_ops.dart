import 'dart:async';

import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:dio/dio.dart';

/// 单文件批处理并发上限：避免同一时间打爆网络 / 图库写入。
const int _maxConcurrency = 3;

class BatchOps {
  BatchOps._();

  /// 批量下载并写入图库。
  ///
  /// 实际下载、相册入库与记录写入全部交给 [ImageDownloader.downloadImage]：
  /// 此前 BatchOps 自己又写了一遍「扩展名判断 + 落盘 + Gal + 写记录」，
  /// 于是修一处漏一处（例如视频帖要按媒体类型分派，两个实现只改一个）。
  ///
  /// [cancelToken] 用于取消：用户在批量下载途中离开页面时停止后续请求。
  static Future<BatchDownloadResult> downloadAll(
    List<String> urls,
    List<String> postIds, {
    List<String>? namespaces,
    String downloadPath = '',
    void Function(int done, int total)? onItemProgress,
    CancelToken? cancelToken,
  }) async {
    final results = <BatchItem?>[];
    results.length = urls.length;
    var done = 0;

    // 整批共用一个 Dio：此前每张图都新建一个 HttpClient，N 张图 = N 个连接池，
    // 同域 keep-alive 全部作废、句柄等到 GC 才回收。
    final dio = DioFactory.createDownload();
    try {
      Future<void> runOne(int i) async {
        if (cancelToken?.isCancelled ?? false) {
          results[i] = BatchItem(url: urls[i], success: false, error: 'cancelled');
          done += 1;
          onItemProgress?.call(done, urls.length);
          return;
        }
        final id = i < postIds.length ? postIds[i] : null;
        final namespace =
            namespaces != null && i < namespaces.length ? namespaces[i] : null;
        final result = await ImageDownloader.downloadImage(
          urls[i],
          postId: id,
          namespace: namespace,
          downloadPath: downloadPath,
          dio: dio,
          cancelToken: cancelToken,
        );
        results[i] = BatchItem(
          url: urls[i],
          success: result.success,
          error: result.error,
        );
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
    } finally {
      dio.close(force: true);
    }

    final nonNull = results.whereType<BatchItem>().toList();
    return BatchDownloadResult(
      items: nonNull,
      successCount: nonNull.where((r) => r.success).length,
      failCount: nonNull.where((r) => !r.success).length,
    );
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
