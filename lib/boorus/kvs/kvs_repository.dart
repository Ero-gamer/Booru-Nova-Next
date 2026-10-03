import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/kvs/parser/kvs_parser.dart';
import 'package:dio/dio.dart';

/// KVS 视频站仓库。
///
/// 与 booru 引擎的关键差别：列表页只有缩略图，播放地址要**打开时按需解析**
/// 详情页（见 [resolvePlaybackUrl]）。因此列表条目里 sample/original 留空，
/// 由查看器调用解析——这也是视频站唯一现实的接入方式（列表页不提供直链）。
class KvsRepository extends BaseBooruRepository {
  KvsRepository({
    required super.dio,
    required super.serverId,
  });

  /// 列表页路径：KVS 的分页在路径尾部 `/search/<tags>/<page>/`。
  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = _encodeTags(query.tags);
    final path = tags.isEmpty
        ? '/latest-updates/${query.page}/'
        : '/search/${_encodeTags(query.tags)}/${query.page}/';

    final response = await dio.get(
      path,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data;
    if (html is! String || html.isEmpty) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = KvsParser.parseList(
      serverId,
      dio.options.baseUrl,
      html,
      limit: query.limit,
    );

    // 分页信号：KVS 列表页没有 count。用「本页是否满员」判断，
    // 空页一定停——避免对不支持的路由反复请求。
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: posts.isNotEmpty && posts.length >= query.limit,
    );
  }

  /// 视频站没有标签建议接口（标签只能从 URL slug 反推）。
  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async => [];

  /// 按需解析播放地址：打开视频时才会调用一次。
  @override
  Future<String?> resolvePlaybackUrl(String postUrl) async {
    if (postUrl.isEmpty) return null;
    try {
      final response = await dio.get(
        postUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String || html.isEmpty) return null;
      return KvsParser.parseVideoPage(html)?.url;
    } catch (_) {
      // 解析失败让查看器显示可重试的错误态，不抛给上层
      return null;
    }
  }

  /// KVS 的标签用 `+` 连接，逐段 percent-encode。
  String _encodeTags(String tags) => tags
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('+');
}
