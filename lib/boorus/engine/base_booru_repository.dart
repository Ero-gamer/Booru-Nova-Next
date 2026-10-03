import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:dio/dio.dart';

/// Booru 引擎仓库基类，收敛各引擎的公共样板。
///
/// 提供 [dio] / [serverId] 字段与统一构造，子类通过
/// `super(dio: dio, serverId: serverId)` 初始化。
/// 收藏相关方法默认返回「不支持」占位，支持收藏的引擎按需 override。
abstract class BaseBooruRepository implements BooruRepository {
  const BaseBooruRepository({
    required this.dio,
    required this.serverId,
  });

  /// 网络请求客户端（已由 DioFactory 配置好 baseUrl 与拦截器）。
  final Dio dio;

  /// 站点标识，用于跨站点缓存隔离。字段即满足接口 getter，子类无需再 override。
  @override
  final String serverId;

  /// 默认实现：引擎不支持图集时返回空列表。
  ///
  /// pool 可用性实测（2026-08）：danbooru / e621 / moebooru 匿名可访问，已各自实现；
  /// gelbooru / rule34 需 api_key+user_id 认证（匿名 401 / Missing authentication），
  /// safebooru 的 DAPI 不支持 pool 接口，sankaku 需 token —— 故这些引擎保持默认空实现，
  /// 属站点认证限制而非实现遗漏。
  @override
  Future<List<BooruPool>> fetchPools({int page = 1, int limit = 20}) async => [];

  /// 默认：本引擎不支持按需解析播放地址（只有视频站需要）。
  ///
  /// 必须在这里给默认实现：子类用的是 `implements BooruRepository`，
  /// 接口的默认函数体不会被继承，缺一个成员就编译不过。
  @override
  Future<String?> resolvePlaybackUrl(String postUrl) async => null;

  @override
  Future<List<String>> fetchTrendingTags({int limit = 20}) async => [];

  /// 拼接搜索标签：把用户输入标签与评级过滤合并为站点查询串。
  ///
  /// [ratingMap] 为引擎特定的评级映射，例如 danbooru 用 `rating:s`，
  /// 多数引擎用 `rating:safe`。不评级过滤时传 null。
  String buildTagsQuery(BooruQuery query, Map<String, String>? ratingMap) {
    return <String>[
      if (query.tags.isNotEmpty) query.tags,
      if (query.rating != null && ratingMap != null)
        ratingMap[query.rating!] ?? 'rating:${query.rating}',
    ].join(' ');
  }

  /// gelbooru 系的认证方式是 **query 参数**（`api_key` + `user_id`），
  /// 不是 HTTP Basic。凭据由 registry 放进 `dio.options.extra`。
  ///
  /// 此前凭据只被拼成 Basic 头，而 gelbooru / rule34 / safebooru 要的是
  /// 这两个参数——用户填了 API Key 也永远 401（本文件注释早已说明这一点）。
  Map<String, dynamic> get authQueryParams {
    final extra = dio.options.extra;
    final login = extra['authLogin'];
    final apiKey = extra['authApiKey'];
    return <String, dynamic>{
      if (apiKey is String && apiKey.isNotEmpty) 'api_key': apiKey,
      if (login is String && login.isNotEmpty) 'user_id': login,
    };
  }

  /// 多数引擎通用的评级映射：safe / questionable / explicit。
  static const Map<String, String> ratingMapLong = {
    's': 'rating:safe',
    'q': 'rating:questionable',
    'e': 'rating:explicit',
  };
}

/// 评级归一：把各站原始取值统一成 UI 唯一认识的短码 `s` / `q` / `e`。
///
/// 各站口径并不一致：safebooru 实测返回短码 `s`，gelbooru 可能返回
/// `general` / `sensitive` 这样的长名，danbooru 用 `g` 表示 general。
/// 不归一就会出现详情页显示 "SENSITIVE"、徽章因为不认这个值而变灰、
/// 同一张图在首页与收藏页颜色不同。
///
/// 未知值落到 `q`（可疑）而不是 `e`：把不确定当限制级会误伤安全筛选，
/// 也会让头图的 [isSafeRating] 直接否掉一条本来可用的候选。
String normalizeRating(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 's':
    case 'safe':
    case 'general':
    case 'g':
      return 's';
    case 'q':
    case 'questionable':
      return 'q';
    case 'e':
    case 'explicit':
      return 'e';
    default:
      return 'q';
  }
}

/// 把解析层 [BooruPost] 转为 UI 层 [PostSummary]。
/// 原先 8 个引擎各有一份逐字节相同的私有扩展，现收敛为一份。
extension BooruPostToSummary on BooruPost {
  PostSummary toSummary(String serverId) => PostSummary(
        id: id,
        serverId: serverId,
        thumbnailUrl: thumbnailUrl,
        sampleUrl: sampleUrl,
        originalUrl: originalUrl,
        tags: tags,
        tagGeneral: tagGeneral,
        tagArtist: tagArtist,
        tagCharacter: tagCharacter,
        tagCopyright: tagCopyright,
        tagMeta: tagMeta,
        aspectRatio: aspectRatio,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source,
        postUrl: postUrl,
      );
}
