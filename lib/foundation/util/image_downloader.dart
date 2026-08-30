import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:gal/gal.dart';

typedef OnProgress = void Function(double progress);

class ImageDownloader {
  ImageDownloader._();

  static Future<DownloadResult> downloadImage(
    String url, {
    String? postId,
    int? width,
    int? height,
    OnProgress? onProgress,
    String downloadPath = '',
  }) async {
    try {
      final dir = await resolveDownloadDir(downloadPath);
      if (!url.split('/').last.contains('.')) {
        return const DownloadResult(success: false, error: 'No file extension');
      }

      final path = '${dir.path}/${uniqueFileName(url, postId: postId)}';
      final dio = DioFactory.createDownload();
      await dio.download(
        url, path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      await Gal.putImage(path);

      if (postId != null) {
        final repo = UserDownloadsRepo();
        await repo.add(DownloadEntry(
          postId: postId,
          imageUrl: url,
          localPath: path,
          downloadedAt: DateTime.now(),
          width: width,
          height: height,
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
