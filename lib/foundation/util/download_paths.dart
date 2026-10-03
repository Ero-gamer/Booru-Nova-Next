import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 解析下载目录：优先用户设置的 [downloadPath]，不可用则回退到默认目录。
///
/// 回退目标必须是**持久**目录：此前回退到 `getTemporaryDirectory()`，那是系统
/// 随时可以回收的缓存目录，「清理缓存」也会把它整个删掉——而下载记录里的
/// localPath 还指着它，文件会凭空消失且用户什么都没做。
Future<Directory> resolveDownloadDir(String downloadPath) async {
  if (downloadPath.isNotEmpty) {
    final dir = Directory(downloadPath);
    try {
      // 配置期一次性目录检查，非热路径；需要确认/创建用户选定目录。
      // ignore: avoid_slow_async_io
      if (await dir.exists()) return dir;
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      // 路径无效（权限/只读等）时回退默认目录，避免下载直接失败。
      // 注意回退到的是持久目录，不是缓存目录。
    }
  }
  return defaultDownloadDir();
}

/// 默认下载目录：app 专属外部目录（`/Android/data/<pkg>/files/…`）。
///
/// 不需要任何存储权限，也不会被系统当缓存回收。取不到时逐级回退到应用文档
/// 目录，最后才是临时目录（极端情况下至少不崩）。
Future<Directory> defaultDownloadDir() async {
  final providers = <Future<Directory?> Function()>[
    getExternalStorageDirectory,
    getApplicationDocumentsDirectory,
  ];
  for (final provider in providers) {
    try {
      final dir = await provider();
      if (dir == null) continue;
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      continue;
    }
  }
  return getTemporaryDirectory();
}

/// URL 的扩展名（含点，已剥掉 query / fragment）。没有扩展名时返回 `''`。
///
/// 全项目**唯一**的扩展名口径：守卫和文件名生成必须用同一个函数，否则会
/// 出现「守卫认为有扩展名 → 放行 → 文件名却没扩展名 → Gal 抛
/// FileNotFoundException → 用户看到"下载失败"，而文件其实已经躺在磁盘上」。
String extensionOf(String url) {
  final raw = url.split('?').first.split('#').first;
  final base = raw.split('/').last;
  final dot = base.lastIndexOf('.');
  return dot > 0 ? base.substring(dot) : '';
}

/// 视频扩展名集合。Gal 按媒体类型写入不同的相册集合，把 mp4 交给图片 API
/// 会在相册里留下一条无法播放的「图片」，甚至被 MediaStore 拒绝。
const Set<String> videoExtensions = {'.mp4', '.webm', '.mov', '.mkv', '.m4v'};

/// 流清单扩展名（HLS / DASH）。
///
/// 它们**不是文件**而是一份播放列表：直接当文件下载只会得到一个几十字节的
/// 文本，写进相册也没法播。视频站常只提供这种地址，所以必须显式识别并拒绝
/// 下载（播放不受影响，播放器原生支持 HLS）。
const Set<String> streamExtensions = {'.m3u8', '.mpd'};

bool isVideoFile(String url) =>
    videoExtensions.contains(extensionOf(url).toLowerCase());

bool isStreamManifest(String url) =>
    streamExtensions.contains(extensionOf(url).toLowerCase());

/// 生成唯一且保留扩展名的文件名，以 [postId] 为前缀，避免同名文件互相覆盖。
///
/// URL 可能带查询参数（如 `photo.jpg?v=123`），文件名主体和扩展名都必须
/// 清洗为 Windows/Android 合法字符，否则 `?`、`=` 等会让写盘失败。
/// 主体长度受限，避免超长 URL 拼出超 MAX_PATH 的路径导致写盘失败。
String uniqueFileName(
  String url, {
  String? postId,
  String? namespace,
}) {
  // 只取路径最后一段，剥掉 query / fragment
  final raw = url.split('?').first.split('#').first;
  final base = raw.split('/').last;
  final ext = extensionOf(url);
  final stem = ext.isEmpty || !base.endsWith(ext)
      ? base
      : base.substring(0, base.length - ext.length);
  final safeStem =
      stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').replaceAll('..', '.');
  // 扩展名同样过白名单：保留字母数字点（如 .jpg .png），其余替换为下划线
  final safeExt = ext.replaceAll(RegExp(r'[^A-Za-z0-9.]'), '_');
  // 主体截断到 60 字符，避免超长路径；扩展名保留（.jpg 等本身不长）
  final trunk = safeStem.length > 60 ? safeStem.substring(0, 60) : safeStem;
  final safeNamespace = namespace == null || namespace.isEmpty
      ? ''
      : '${namespace.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_';
  final safeId = postId == null || postId.isEmpty
      ? ''
      : '${postId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_';
  return '$safeNamespace$safeId$trunk$safeExt';
}
