import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

/// Shimmie2 / paheal 系图站的解析。
///
/// 两种输入：
/// - 新版 Shimmie 的 JSON（`/api/post/list`）：字段是
///   `id / file / preview / sample / width / height / tags / rating`；
/// - 老 paheal 的图库 HTML（`/post/list/<tags>/<page>`）：详情链接形如
///   `/post/view/<id>`，缩略图在 `_thumbs` 目录下。
///
/// 与 KVS 一样，本环境无法访问这些域名，所以两种输入都写成容错解析，
/// 测试用按结构构造的固件。缺字段一律跳过而不是抛错——宁可少一条，
/// 也不能让整页加载失败。
class Shimmie2Parser {
  Shimmie2Parser._();

  /// JSON 接口：顶层可能是数组，也可能包一层（`{"posts": [...]}`）。
  static List<BooruPost> parseJson(String serverId, Object? decoded) {
    final raw = decoded is Map
        ? (decoded['posts'] ?? decoded['post'] ?? decoded['data'])
        : decoded;
    if (raw is! List) return const [];

    final posts = <BooruPost>[];
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final file = _str(map['file']) ?? _str(map['image']) ?? '';
      final preview = _str(map['preview']) ?? _str(map['thumbnail']) ?? '';
      final sample = _str(map['sample']) ?? '';
      // 没有任何可用媒体地址的条目直接跳过：放进去只会渲染成一张破图。
      if (file.isEmpty && preview.isEmpty) continue;

      final width = _int(map['width']);
      final height = _int(map['height']);
      final tagList = map['tags'];
      final tags = tagList is List
          ? tagList.whereType<String>().toList()
          : (tagList is String ? tagList.split(' ').where((t) => t.isNotEmpty).toList() : <String>[]);

      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        // 缩略图优先 preview，其次直接拿原图（老分支常只有 file）
        thumbnailUrl: preview.isNotEmpty ? preview : file,
        sampleUrl: sample,
        originalUrl: file,
        tags: tags,
        aspectRatio: (width != null && height != null && height > 0)
            ? width / height
            : 1.0,
        width: width ?? 0,
        height: height ?? 0,
        rating: normalizeRating(_str(map['rating'])),
        score: _int(map['score']) ?? 0,
        source: _str(map['source']),
        postUrl: _str(map['post_url']),
      ));
    }
    return posts;
  }

  /// 图库 HTML：从 `/post/view/<id>` 链接反推条目。
  static List<BooruPost> parseList(
    String serverId,
    String baseUrl,
    String html, {
    int limit = 40,
  }) {
    final posts = <BooruPost>[];
    final seen = <String>{};

    final linkPattern = RegExp(
      r'''<a[^>]+href=["']([^"']*?/post/view/(\d+)[^"']*)["'][^>]*>(.*?)</a>''',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in linkPattern.allMatches(html)) {
      if (posts.length >= limit) break;
      final id = match.group(2) ?? '';
      if (id.isEmpty || !seen.add(id)) continue;

      final inner = match.group(3) ?? '';
      final thumb = _firstImage(inner) ??
          _firstImage(match.group(0) ?? '') ??
          _firstImage(_window(html, match.end));
      if (thumb == null) continue;

      final alt = _attr(match.group(0) ?? '', 'alt') ?? '';
      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: _absolute(thumb, baseUrl),
        // 原图地址要进详情页才知道；列表页只给缩略图。
        sampleUrl: '',
        originalUrl: '',
        tags: alt.isEmpty
            ? const []
            : alt.split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).toList(),
        aspectRatio: 1.0,
        width: 0,
        height: 0,
        // paheal 系没有分级字段：按可疑记录，安全筛选不会把它当成安全图。
        rating: 'q',
        score: 0,
        postUrl: _absolute('/post/view/$id', baseUrl),
      ));
    }
    return posts;
  }

  static String? _firstImage(String html) {
    if (html.isEmpty) return null;
    // 允许相对路径，由 _absolute 补齐域名
    final match = RegExp(
      '''(?:data-original|data-src|src)=["']([^"']+?\\.(?:jpe?g|png|webp|gif)(?:\\?[^"']*)?)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  static String _window(String html, int from) {
    if (from >= html.length) return '';
    return html.substring(from, (from + 600).clamp(0, html.length));
  }

  static String? _attr(String tag, String name) {
    final match =
        RegExp('$name=["\'](.*?)["\']', caseSensitive: false).firstMatch(tag);
    return match?.group(1)?.trim();
  }

  static String _absolute(String url, String baseUrl) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  static String? _str(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
