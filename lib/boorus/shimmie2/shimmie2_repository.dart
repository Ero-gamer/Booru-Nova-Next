import 'dart:convert';

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/shimmie2/parser/shimmie2_parser.dart';
import 'package:dio/dio.dart';

/// Shimmie2 / paheal 系图站仓库（rule34.paheal.net、allgirls.paheal.net 等）。
///
/// 这一族与 gelbooru DAPI 完全不同，也与 shimmie2 官方新版不同——paheal 是很
/// 早的分支，现实里能用的是**图库 HTML 页面**：
///   `/post/list/<tags>/<page>`
/// 因此这里两条路都试：先试新版 Shimmie 的 JSON 接口（官方 2.11+ 有
/// `/api/post/list`），拿到 JSON 就按 JSON 解；否则退回 HTML 解析。
class Shimmie2Repository extends BaseBooruRepository {
  Shimmie2Repository({
    required super.dio,
    required super.serverId,
  });

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    // 先试 JSON 接口：有就是结构化的，省掉解析 HTML 的脆弱性
    final json = await _tryJsonApi(query);
    if (json != null) return json;

    // 退回 HTML 图库页
    final tags = _encodeTags(query.tags);
    final path = tags.isEmpty
        ? '/post/list/${query.page}'
        : '/post/list/$tags/${query.page}';
    final response = await dio.get(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data;
    if (html is! String || html.isEmpty) {
      return const BooruPageResult(posts: [], hasMore: false);
    }
    final posts = Shimmie2Parser.parseList(
      serverId,
      dio.options.baseUrl,
      html,
      limit: query.limit,
    );
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.isNotEmpty && posts.length >= query.limit,
    );
  }

  /// 新版 Shimmie 的 JSON 接口。失败/不存在时返回 null，由调用方退回 HTML。
  Future<BooruPageResult?> _tryJsonApi(BooruQuery query) async {
    try {
      final response = await dio.get(
        '/api/post/list',
        queryParameters: {
          'query': query.tags,
          'limit': query.limit,
          'page': query.page,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data is! String || data.trimLeft().startsWith('<')) return null;
      final decoded = jsonDecode(data);
      final posts = Shimmie2Parser.parseJson(serverId, decoded);
      if (posts.isEmpty) return null;
      return BooruPageResult(
        posts: posts.map((p) => p.toSummary(serverId)).toList(),
        hasMore: posts.length >= query.limit,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    // Shimmie2 的标签接口同样是 HTML（/tags）；标签建议对本族站点意义有限，
    // 与其猜一个可能不存在的端点，不如老实返回空——UI 会显示"无建议"。
    return [];
  }

  String _encodeTags(String tags) => tags
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('+');
}
