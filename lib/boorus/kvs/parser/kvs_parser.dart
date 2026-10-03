import 'package:boorunova/data/repository/booru/entity/post.dart';

/// KVS（Kernel Video Sharing）站点的解析。
///
/// 这一族 CMS 的 HTML 结构在几百个站点上高度一致，但**并非同一份模板**，
/// 所以这里的策略是「按优先级找，找不到就退一步」：
/// 列表页从 `/videos/<id>/<slug>/` 这种链接反推条目与缩略图；
/// 详情页先解 `flashvars`（官方播放器配置），失败再全局找媒体直链。
///
/// 说明：本环境对这些域名做了污染（解析到假 IP），无法用真实页面验证，
/// 因此解析全部写成容错的，配套测试用的是按家族结构构造的固件。
/// 真机上用「探测」页确认一次即可。
class KvsParser {
  KvsParser._();

  /// 视频页里能拿到的播放信息。
  static const List<String> _videoKeys = [
    'video_url',
    'video_alt_url',
    'video_alt_url2',
    'video_alt_url3',
  ];

  /// 解析列表页，抽出视频条目（id / 缩略图 / 标题 / 时长）。
  static List<BooruPost> parseList(
    String serverId,
    String baseUrl,
    String html, {
    int limit = 40,
  }) {
    final posts = <BooruPost>[];
    final seen = <String>{};

    // 视频链接：KVS 的详情页固定形如 /videos/<数字 id>/<slug>/
    final linkPattern = RegExp(
      r'''<a[^>]+href=["']([^"']*?/videos?/(\d+)/[^"']*)["'][^>]*>(.*?)</a>''',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in linkPattern.allMatches(html)) {
      if (posts.length >= limit) break;
      final href = match.group(1) ?? '';
      final id = match.group(2) ?? '';
      final inner = match.group(3) ?? '';
      if (id.isEmpty || !seen.add(id)) continue;

      // 缩略图：缩略图常见于内层 img，也可能挂在 a 的 data-* 上
      final thumb = _firstMediaUrl(inner) ??
          _firstMediaUrl(match.group(0) ?? '') ??
          // 有的主题把 img 放在链接之后：往后取一小段窗口兜底
          _firstMediaUrl(_window(html, match.end));
      if (thumb == null) continue;

      final title = _attr(match.group(0) ?? '', 'title') ?? '';
      final duration = _durationNear(html, match.end);
      final slug = href.split('/').where((s) => s.isNotEmpty).last;

      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: _absolute(thumb, baseUrl),
        // 播放地址要打开详情页才知道：留空，由 resolvePlaybackUrl 按需解析。
        sampleUrl: '',
        originalUrl: '',
        // 标签有两个来源：URL slug 与链接 title。视频站不提供标签字段，
        // 这两个是唯一能免费拿到的，够黑名单与标签展示用。
        tags: [
          ..._tagsFromSlug(slug),
          ..._tagsFromText(title),
        ],
        // 列表页拿不到真实比例，按 16:9 估；视频站缩略图基本是这个比例。
        aspectRatio: 16 / 9,
        width: 0,
        height: 0,
        // 视频站是成人内容站：按限制级记录，安全筛选与侧栏头图自然避开它。
        rating: 'e',
        score: 0,
        postUrl: _absolute(href, baseUrl),
        uploader: duration,
      ));
    }
    return posts;
  }

  /// 解析详情页，返回「可播放地址」与「缩略图/海报」。
  static KvsVideo? parseVideoPage(String html) {
    final fields = _parseFlashvars(html);

    // 优先级：mp4 优先（能播也能存），流清单兜底（能播不能存）。
    // KVS 的 video_url 通常是最低档 mp4，video_alt_url/2 是 720/1080。
    final candidates = <String?>[
      fields['video_alt_url2'],
      fields['video_alt_url3'],
      fields['video_alt_url'],
      fields['video_url'],
    ];
    String? playable;
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final current = playable;
      if (current == null || _prefer(candidate, current)) {
        playable = candidate;
      }
    }

    // flashvars 里没有（新版播放器把配置塞在别处）→ 全局找媒体直链
    playable ??= _bestMediaUrl(html);
    if (playable == null || playable.isEmpty) return null;

    return KvsVideo(
      url: playable,
      poster: fields['poster'] ?? fields['preview_url'],
    );
  }

  /// mp4 优于流清单：能播也能存。
  static bool _prefer(String candidate, String current) {
    final cStream = _isStream(candidate);
    final curStream = _isStream(current);
    if (cStream != curStream) return curStream;
    return false;
  }

  static bool _isStream(String url) {
    final bare = url.split('?').first.toLowerCase();
    return bare.endsWith('.m3u8') || bare.endsWith('.mpd');
  }

  /// 解 `var flashvars = { ... };` 里的键值对。
  ///
  /// 值可能是单引号/双引号字符串，也可能带转义斜杠（`https:\/\/`）——
  /// 后者在 KVS 里很常见，必须先反转义。
  static Map<String, String> _parseFlashvars(String html) {
    final result = <String, String>{};
    final block = RegExp(r'flashvars\s*=\s*\{', caseSensitive: false)
        .firstMatch(html);
    if (block == null) return result;

    // 从 { 起做括号配平，避免把后面的脚本一起吞进来
    final start = html.indexOf('{', block.start);
    var depth = 0;
    var end = start;
    for (var i = start; i < html.length; i++) {
      final ch = html[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    if (end <= start) return result;
    final body = html.substring(start + 1, end);

    for (final key in _videoKeys) {
      final value = _jsString(body, key);
      if (value != null) result[key] = value;
    }
    result['poster'] = _jsString(body, 'poster') ?? _jsString(body, 'preview_url') ?? '';
    // 去掉空值，调用方只需判 containsKey
    result.removeWhere((_, v) => v.isEmpty);
    return result;
  }

  static String? _jsString(String body, String key) {
    final match = RegExp(
      """['"]?$key['"]?\\s*:\\s*['"](.*?)['"]""",
      dotAll: true,
    ).firstMatch(body);
    if (match == null) return null;
    return (match.group(1) ?? '').replaceAll(r'\/', '/').replaceAll(r'\u002F', '/').trim();
  }

  static String? _bestMediaUrl(String html) {
    // 优先 mp4，其次 m3u8/mpd
    final mp4 = RegExp(r'''https?://[^"'\s\\]+?\.(?:mp4|webm)(?:\?[^"'\s\\]*)?''',
            caseSensitive: false)
        .firstMatch(html)
        ?.group(0);
    if (mp4 != null) return mp4.replaceAll(r'\/', '/');
    final stream =
        RegExp(r'''https?://[^"'\s\\]+?\.(?:m3u8|mpd)(?:\?[^"'\s\\]*)?''',
                caseSensitive: false)
            .firstMatch(html)
            ?.group(0);
    return stream?.replaceAll(r'\/', '/');
  }

  static String? _firstMediaUrl(String html) {
    if (html.isEmpty) return null;
    // 允许相对路径（有的主题给 `/thumbs/xxx.jpg`），由 _absolute 补齐域名
    final match = RegExp(
      '''(?:data-original|data-src|data-webp|data-lazy|src|poster)=["']([^"']+?\\.(?:jpe?g|png|webp|gif)(?:\\?[^"']*)?)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  static String _window(String html, int from) {
    if (from >= html.length) return '';
    final end = (from + 600).clamp(0, html.length);
    return html.substring(from, end);
  }

  static String? _durationNear(String html, int from) {
    final window = _window(html, from);
    final match = RegExp(r'''class=["'][^"']*duration[^"']*["'][^>]*>\s*([0-9:]+)''')
        .firstMatch(window);
    final value = match?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String? _attr(String tag, String name) {
    final match = RegExp('$name=["\'](.*?)["\']', caseSensitive: false)
        .firstMatch(tag);
    return match?.group(1)?.trim();
  }

  /// 从 URL slug 反推标签：`big-breast-blonde-3d` → [big breast blonde 3d]
  /// 这是视频站唯一能免费拿到的标签来源，够黑名单与标签展示用。
  static List<String> _tagsFromSlug(String slug) {
    final clean = slug.replaceAll(RegExp(r'\.(html?|php)$'), '');
    return clean
        .split(RegExp(r'[-_+]'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty && !RegExp(r'^\d+$').hasMatch(t))
        .toList();
  }

  /// 从标题反推标签（`title="Big Breast Blonde 3D"`）。
  static List<String> _tagsFromText(String text) {
    if (text.isEmpty) return const [];
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 1 && !RegExp(r'^\d+$').hasMatch(t))
        .toList();
  }

  static String _absolute(String url, String baseUrl) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }
}

/// 详情页解析结果。
class KvsVideo {
  const KvsVideo({required this.url, this.poster});

  /// 可播放地址（mp4 或 HLS 清单）。
  final String url;

  /// 海报图（可能为空）。
  final String? poster;
}
