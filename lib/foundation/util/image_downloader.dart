import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

typedef OnProgress = void Function(double progress);

class ImageDownloader {
  ImageDownloader._();

  /// 下载单张媒体并存进系统相册，同时写一条下载记录。
  ///
  /// [dio] 用于批量下载复用同一个连接池：此前每张图都 `createDownload()`
  /// 新建一个 HttpClient，N 张图建 N 个连接池，同域 keep-alive 全部作废。
  /// 自己创建时自己负责 `close`。
  static Future<DownloadResult> downloadImage(
    String url, {
    String? postId,
    String? namespace,
    int? width,
    int? height,
    OnProgress? onProgress,
    String downloadPath = '',
    Dio? dio,
    CancelToken? cancelToken,
  }) async {
    try {
      // 扩展名口径只有一处：这里与文件名生成用同一个函数，避免
      // 「守卫放行 → 文件名无扩展名 → Gal 抛异常 → 报失败但文件已落盘」。
      final extension = extensionOf(url);
      if (extension.isEmpty) {
        return const DownloadResult(
          success: false,
          error: 'No file extension in url',
        );
      }

      // 流清单（m3u8/mpd）不是文件：下载下来只有几十字节的文本，
      // 存进相册也没法播。明确拒绝并给出可读原因，而不是写一个假文件。
      // 播放不受影响——播放器原生支持 HLS。
      if (isStreamManifest(url)) {
        return const DownloadResult(
          success: false,
          error: 'stream manifest is not downloadable',
        );
      }

      final dir = await resolveDownloadDir(downloadPath);
      final path =
          '${dir.path}/${uniqueFileName(url, postId: postId, namespace: namespace)}';

      final client = dio ?? DioFactory.createDownload();
      try {
        await client.download(
          url,
          path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0 && onProgress != null) {
              onProgress(received / total);
            }
          },
        );
      } finally {
        if (dio == null) client.close(force: true);
      }

      // 按媒体类型分派：mp4/webm 必须走视频集合，否则相册里会出现一条
      // 无法播放的"图片"，或被 MediaStore 直接拒绝而报下载失败。
      if (isVideoFile(url)) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }

      if (postId != null) {
        final repo = UserDownloadsRepo();
        await repo.add(DownloadEntry(
          postId: postId,
          imageUrl: url,
          localPath: path,
          downloadedAt: DateTime.now(),
          width: width,
          height: height,
          // namespace 就是 serverId：写进记录，删除时才能按站点精确定位。
          serverId: namespace ?? '',
        ));
      }

      return const DownloadResult(success: true);
    } catch (e) {
      return DownloadResult(success: false, error: e.toString());
    }
  }
}

class DownloadResult {
  const DownloadResult({required this.success, this.error});

  final bool success;
  final String? error;
}
