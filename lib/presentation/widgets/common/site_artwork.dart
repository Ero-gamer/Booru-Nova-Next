import 'dart:math';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/booru/site_artwork.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 侧栏头图：当前站点随机一张「正常向」帖子的预览图，点一下进帖子查看器。
///
/// 三个约束：
/// - 图来自用户正在用的站点（见 [siteArtworkPostsProvider]），不是公开图库；
/// - 只显示安全评级的非视频帖，候选里一张合格的都没有就回落主题渐变——
///   头图是装饰，任何失败都不该影响导航；
/// - 黑名单照旧生效：用户说了不想看到某些标签，头图没有理由绕过它。
class SiteArtwork extends ConsumerStatefulWidget {
  const SiteArtwork({super.key, this.onTap});

  /// 点击头图。参数是候选列表与当前这张的下标，调用方据此进查看器，
  /// 于是「点左右滑动看同一批候选」也能用。
  final void Function(List<PostSummary> posts, int index)? onTap;

  @override
  ConsumerState<SiteArtwork> createState() => _SiteArtworkState();
}

class _SiteArtworkState extends ConsumerState<SiteArtwork> {
  static final Random _random = Random();

  /// 一次展示最多试几张。第一张图加载失败就换下一张，比直接显示灰块强；
  /// 但也不能把整页候选挨个试一遍——那是四十次注定失败的请求。
  static const int _maxAttempts = 3;

  /// 本次展示挑中的下标。为 null 表示还没挑过（候选还没到）。
  int? _picked;

  int _attempts = 0;

  /// 是否已经安排了「换下一张」的重建，避免同一帧里连续跳好几张。
  bool _advancing = false;

  /// 取本次要显示的下标：进来时随机一次，之后在本次展示内固定住。
  ///
  /// 固定的必要性在于 build 会因主题/黑名单等变化反复调用，
  /// 每次重新 random 会让头图在用户眼皮底下跳图。
  int _pickIndex(int length) {
    final cached = _picked;
    if (cached != null && cached < length) return cached;
    final next = _random.nextInt(length);
    _picked = next;
    return next;
  }

  void _onTap(List<PostSummary> posts, int index) {
    widget.onTap?.call(posts, index);
  }

  /// 图片加载失败 → 换下一张候选。只在还有尝试额度时换。
  void _tryNext(List<PostSummary> posts) {
    if (_advancing || _attempts + 1 >= _maxAttempts || posts.length < 2) return;
    _advancing = true;
    final next = ((_picked ?? 0) + 1) % posts.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _picked = next;
        _attempts++;
        _advancing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final serverId = ref.watch(booruPageStateProvider.select((s) => s.serverId));
    final candidates = serverId == null
        ? const <PostSummary>[]
        : ref.watch(siteArtworkPostsProvider(serverId)).valueOrNull ??
            const <PostSummary>[];

    // 黑名单过滤放在这里而不是 provider 里：屏蔽列表随时会变，
    // 放进 provider 会让改一次黑名单就重打一遍站点接口。
    final blocked = ref.watch(tagsBlockerStateProvider);
    final blockedNames = blocked.values.map((t) => t.name).toSet();
    final posts = blockedNames.isEmpty
        ? candidates
        : candidates
            .where((p) => !p.tags.any(blockedNames.contains))
            .toList(growable: false);

    if (posts.isEmpty) return const _ArtworkFallback();

    final index = _pickIndex(posts.length);
    final post = posts[index];
    final tappable = widget.onTap != null;

    return GestureDetector(
      // opaque：图片未铺满（比如留白）时，空白处也该能点开帖子。
      behavior: HitTestBehavior.opaque,
      onTap: tappable ? () => _onTap(posts, index) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExtendedImage.network(
            post.thumbnailUrl,
            fit: BoxFit.cover,
            cache: true,
            cacheMaxAge: const Duration(days: 7),
            // 头图最宽也就抽屉那么宽，没必要按原图分辨率解码。
            cacheWidth: 900,
            // 装饰图不值得让用户盯着占位等半分钟：超时就换下一张候选。
            timeLimit: const Duration(seconds: 8),
            retries: 1,
            gaplessPlayback: true,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.failed) {
                _tryNext(posts);
                return const _ArtworkFallback();
              }
              if (state.extendedImageLoadState == LoadState.completed) {
                return state.completedWidget;
              }
              return const _ArtworkFallback();
            },
          ),
          // 可点的提示：不然用户不会知道这张图能点开。
          if (tappable)
            Positioned(
              top: 10,
              right: 10,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_in_full,
                      size: 13, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 没有可用站点 / 候选为空 / 图片还在路上时的兜底：主题渐变。
///
/// 不能留白：头图区域是纯装饰，空白会让滑出的抽屉看起来像没加载完。
/// 渐变最终会被头部的压暗层盖住，所以只用亮色即可，不必考虑对比度。
class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.85),
              colorScheme.primaryContainer,
              colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
      ),
    );
  }
}
