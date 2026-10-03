import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';

class Rule34Parser {
  Rule34Parser._();

  static const _siteUrl = 'https://rule34.xxx';

  static String _abs(String url) {
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  static List<BooruPost> parsePosts(
    String serverId,
    List<dynamic> json,
  ) {
    return json.whereType<Map<String, dynamic>>().map((post) {
      final id = post['id']?.toString() ?? '';
      var fileUrl = _abs((post['file_url'] as String?) ?? '');
      var sampleUrl = _abs((post['sample_url'] as String?) ?? '');
      final previewUrl = _abs((post['preview_url'] as String?) ?? '');
      final tags = (post['tags'] as String?) ?? '';
      final width = (post['width'] as int?) ?? 0;
      final height = (post['height'] as int?) ?? 0;
      final rating = _normalizeRating(post['rating'] as String? ?? '');
      final score = (post['score'] as int?) ?? 0;
      final source = _abs((post['source'] as String?) ?? '');

      if (sampleUrl.isEmpty) sampleUrl = fileUrl;

      return BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl,
        originalUrl: fileUrl,
        tags: tags.isEmpty ? [] : tags.split(' '),
        aspectRatio: height > 0 ? width / height : 1.0,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: id.isEmpty ? null : '$_siteUrl/index.php?page=post&s=view&id=$id',
        uploader: null,
      );
    }).toList();
  }

  static List<String> parseSuggestions(List<dynamic> json) {
    return json.whereType<Map<String, dynamic>>().map((tag) {
      return (tag['tag'] as String?) ?? '';
    }).where((name) => name.isNotEmpty).toList();
  }

  /// 评级归一交给共享实现：此前这里的未知值落到 `e`（限制级），
  /// 字段缺失或站点新增枚举都会被当成限制级，安全筛选与头图判定随之出错。
  static String _normalizeRating(String rating) => normalizeRating(rating);
}
