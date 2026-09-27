import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 解析下载目录：优先用户设置的 [downloadPath]，不可用则回退到系统临时目录。
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
      // 路径无效（权限/只读等）时回退临时目录，避免下载失败。
    }
  }
  return getTemporaryDirectory();
}

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
  final dot = base.lastIndexOf('.');
  final stem = base.substring(0, dot > 0 ? dot : base.length);
  final ext = dot > 0 ? base.substring(dot) : '';
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
