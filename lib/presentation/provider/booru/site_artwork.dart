import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 侧栏头图候选：当前站点随机一页「正常向」帖子。
///
/// 图片来源是用户正在用的站点，而不是公开图库：侧栏贴着应用的内容生态，
/// 用站点自己的图才不会有「这图哪来的」的割裂感，也不额外依赖第三方服务。
///
/// 按 serverId 缓存整个会话（[Ref.keepAlive]）：抽屉每次滑出都打一遍站点
/// 接口只为看同一张图，纯属浪费；缓存一页候选后由 UI 每次随机取一张，
/// 既省请求又有变化。只缓存非空结果——空结果多半是断网或站点抽风，
/// 把它留住会让头图直到重启都恢复不了。
final siteArtworkPostsProvider =
    FutureProvider.autoDispose.family<List<PostSummary>, String>(
  (ref, serverId) async {
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    // 站点还没选好，或已经切走：不要拿上一个站点的图当这个站点的头图。
    if (repo == null || repo.serverId != serverId) return const [];

    final posts = await fetchArtworkCandidates(repo);
    if (posts.isNotEmpty) ref.keepAlive();
    return posts;
  },
);

/// 一次取多少条候选。取一页而不是一条：随机挑一条要请求一次，
/// 一页足够支撑一整个会话的随机头图。
const int _pageSize = 40;

/// 头图请求用的评级短代码：沿用全应用「安全」的口径（各引擎自己映射成
/// `rating:s` / `rating:safe`）。
///
/// 头图是应用外壳的一部分，不跟着用户的搜索筛选走——筛选可能是「限制级」，
/// 但导航侧栏不该出现那种图。
const String kArtworkRating = 's';

/// 拉取一批可用的头图候选；拉不到就返回空列表（调用方回落主题渐变）。
Future<List<PostSummary>> fetchArtworkCandidates(BooruRepository repo) async {
  // 优先让站点自己随机。不支持 `order:random` 的引擎（gelbooru / rule34 的
  // DAPI）会把它当成普通标签从而返回空结果，于是退回默认排序再取一页——
  // 头图只要「一张看得过去的图」，不值得为了随机性把功能做没。
  for (final tags in const ['order:random', '']) {
    try {
      final result = await repo.searchPosts(
        BooruQuery(tags: tags, limit: _pageSize, rating: kArtworkRating),
      );
      final usable =
          result.posts.where(usableForArtwork).toList(growable: false);
      if (usable.isNotEmpty) return usable;
    } catch (_) {
      // 换下一种查询继续试；两种都失败就是空列表，头图回落渐变。
    }
  }
  return const [];
}

/// 这张帖子的图能不能拿来当头图。
bool usableForArtwork(PostSummary post) =>
    // 视频帖交给图片组件只会渲染失败，查看器里才有意义。
    !isVideoPost(post) &&
    post.thumbnailUrl.isNotEmpty &&
    // 站点忽略评级标签时（或者解析器没给评级），客户端再兜一层。
    isSafeRating(post.rating);

/// 解析出来的评级是否属于「正常向」。
///
/// 各引擎给的值并不统一：danbooru 用 g/s/q/e，其余多为 s/q/e 或
/// safe/questionable/explicit，zerochan 直接硬编码 s。只放行明确表示
/// 安全/普通的取值，其余（含未知值）一律不用——头图宁可退化成渐变，
/// 也不该把限制级图片贴到导航侧栏上。
///
/// `s` 在这里算安全：多数引擎的 `s` 就是 safe，也是全应用「安全」筛选的
/// 短代码（见搜索页分级筛选），与搜索行为保持一致。
bool isSafeRating(String rating) {
  switch (rating.trim().toLowerCase()) {
    case 's':
    case 'safe':
    case 'g':
    case 'general':
      return true;
    default:
      return false;
  }
}
