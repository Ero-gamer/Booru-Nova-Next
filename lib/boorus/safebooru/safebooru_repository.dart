import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/gelbooru_v2/parser/gelbooru_v2_parser.dart';

class SafebooruRepository extends BaseBooruRepository {
  SafebooruRepository({
    required super.dio,
    required super.serverId,
  });

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final tags = buildTagsQuery(query, BaseBooruRepository.ratingMapLong);

    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': tags,
        'pid': query.page - 1,
        'limit': query.limit,
        ...authQueryParams,
      },
    );

    final xml = response.data;
    // 守卫用 `<post` + 空白/`>`：`contains('<post')` 对零结果响应
    // `<posts count="0" offset="0">` 也成立，等于没有守卫。
    if (xml is! String || !RegExp(r'<post[\s>]').hasMatch(xml)) {
      return const BooruPageResult(posts: [], hasMore: false);
    }

    final posts = GelbooruV2Parser.parsePosts(
      serverId,
      dio.options.baseUrl,
      xml,
    );
    // 分页用响应自带的 count/offset（实测 `<posts count="6960037" offset="0">`）。
    // 用「本页条数 >= limit」推断会在解析过滤掉一条时误判为末页。
    final count = GelbooruV2Parser.parseCount(xml);
    final offset = GelbooruV2Parser.parseOffset(xml);
    return BooruPageResult(
      posts: posts.map((p) => p.toSummary(serverId)).toList(),
      hasMore: (count != null && offset != null)
          ? offset + posts.length < count
          : posts.length >= query.limit,
    );
  }

  @override
  Future<List<String>> suggestTags(String query, {int limit = 10}) async {
    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'name_pattern': '%$query%',
        'orderby': 'count',
        'limit': limit,
      },
    );

    final xml = response.data;
    if (xml is! String || !xml.contains('<tag')) return [];

    return GelbooruV2Parser.parseSuggestions(xml);
  }

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async {
    final response = await dio.get(
      '/index.php',
      queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'orderby': 'count',
        'limit': limit,
      },
    );
    final xml = response.data;
    if (xml is! String || !xml.contains('<tag')) return [];
    return GelbooruV2Parser.parseSuggestions(xml);
  }

}
