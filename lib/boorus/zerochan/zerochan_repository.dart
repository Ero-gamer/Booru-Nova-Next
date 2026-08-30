import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/zerochan/parser/zerochan_parser.dart';

class ZerochanRepository extends BaseBooruRepository {
  ZerochanRepository({
    required super.dio,
    required super.serverId,
  });

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = query.tags.isEmpty ? 'index' : _encodeTags(query.tags);
    final response = await dio.get(
      '/$tags',
      queryParameters: {
        // 用真实值而不是 null：Dio 可能丢弃 null 参数，导致请求不带 json 标志而返回 HTML。
        'json': '1',
        'p': query.page,
        'l': query.limit,
      },
    );

    final data = response.data;
    if (data is! Map) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final map = Map<String, dynamic>.from(data);
    final posts = ZerochanParser.parsePosts(serverId, map,
        baseUrl: dio.options.baseUrl);
    final total = map['total'] as int? ?? 0;
    final hasMore = posts.isNotEmpty &&
        (map['pages'] as int? ?? 1) > query.page;

    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: hasMore || (total > query.page * query.limit),
    );
  }

  String _encodeTags(String tags) {
    return tags.split(RegExp(r'\s+')).join('+');
  }

  /// zerochan 无标签建议 API，返回空。
  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    return [];
  }

  /// zerochan 无热门标签 API，返回空。
  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    return [];
  }
}
