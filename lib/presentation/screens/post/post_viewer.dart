import 'dart:async';

import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/foundation/util/image_downloader.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/download_progress.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/media/video_viewer.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class PostViewer extends ConsumerStatefulWidget {
  const PostViewer({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  final List<PostSummary> posts;
  final int initialIndex;

  @override
  ConsumerState<PostViewer> createState() => _PostViewerState();
}

class _PostViewerState extends ConsumerState<PostViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _saving = false;
  bool _slideshowPlaying = false;
  Timer? _slideshowTimer;

  // 跟手下滑 dismiss 状态
  final _dragOffset = ValueNotifier<double>(0);

  // 缩放控制器。doubleTapAction == 'zoom' 依赖它做双击放大/还原；
  // 此前 InteractiveViewer 没有 controller，双击缩放根本无法实现。
  final _zoomController = TransformationController();
  bool _zoomed = false;
  late final AnimationController _springController;
  Animation<double>? _springAnim;
  VoidCallback? _springListener;

  static const _dismissThreshold = 140.0; // 超过此位移松手即关闭

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
    ));
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _trackHistory(widget.posts[_currentIndex]);
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _springController.dispose();
    _dragOffset.dispose();
    _zoomController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSlideshow() {
    if (_slideshowPlaying) {
      _slideshowTimer?.cancel();
      setState(() => _slideshowPlaying = false);
    } else {
      final interval = ref.read(settingsProvider).slideshowInterval;
      _slideshowTimer = Timer.periodic(Duration(seconds: interval), (_) {
        if (_currentIndex < widget.posts.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        } else {
          _slideshowTimer?.cancel();
          setState(() => _slideshowPlaying = false);
        }
      });
      setState(() => _slideshowPlaying = true);
    }
  }

  void _trackHistory(PostSummary post) {
    ref.read(userHistoryRepoProvider).add(post);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.posts[_currentIndex];
    final favRepo = ref.watch(userFavoritesRepoProvider);
    final isFav = favRepo.isFavorite(post.id, serverId: post.serverId);
    final isVideo = isVideoPost(post);
    // 翻页方向：true=横向翻页（纵轴留给下滑关闭），false=纵向翻页（横轴留给侧滑关闭）
    final horizontalPages = ref.watch(settingsProvider).viewerSwipeMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) {
            final fade = 1.0 - (offset.abs() / 400).clamp(0.0, 1.0);
            return Opacity(opacity: fade, child: child);
          },
          child: GlassContainer(
            borderRadius: BorderRadius.zero,
            tint: Colors.black,
            child: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                '${_currentIndex + 1} / ${widget.posts.length}',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                if (widget.posts.length > 1 && !isVideo)
                  IconButton(
                    icon: Icon(_slideshowPlaying
                        ? Icons.pause_circle_filled
                        : Icons.auto_awesome),
                    tooltip:
                        _slideshowPlaying ? T.stopSlideshow : T.autoSlideshow,
                    onPressed: _toggleSlideshow,
                  ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: T.share,
                  onPressed: () => _share(post),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: T.postDetails,
                  onPressed: () => _showDetails(context, post),
                ),
                IconButton(
                  icon: _saving
                      ? _DownloadProgressIcon(post: post)
                      : const Icon(Icons.download_outlined),
                  tooltip: T.downloads,
                  onPressed: _saving ? null : () => _download(post),
                ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.white,
                  ),
                  tooltip: T.favorites,
                  // 按钮态不弹提示：图标翻转本身就是反馈，
                  // 长按/双击才需要 snackbar 确认（手势没有可见的视觉变化）
                  onPressed: () => _toggleFavorite(post, notify: false),
                ),
              ],
            ),
          ),
        ),
      ),
      // 手势接线：四个设置项此前只有 tapAction / swipeDownAction 生效，
      // doubleTapAction 与 longPressAction 声明了但没有任何消费点。
      //
      // 长按此前被 _toggleSlideshow 无条件抢占，用户把长按设成「收藏」
      // 实际行为却是切幻灯片 —— 语义直接冲突。这里改为按设置分发，
      // 幻灯片移交给 AppBar 上的显式按钮（本来就有）。
      body: GestureDetector(
        onLongPress: () => _onLongPress(post),
        onDoubleTap: () => _onDoubleTap(post),
        onVerticalDragStart:
            horizontalPages ? (_) => _springController.stop() : null,
        onVerticalDragUpdate:
            horizontalPages ? (d) => _dragOffset.value += d.delta.dy : null,
        onVerticalDragEnd: horizontalPages ? (d) => _onDragEnd(d, post) : null,
        onHorizontalDragStart:
            horizontalPages ? null : (_) => _springController.stop(),
        onHorizontalDragUpdate:
            horizontalPages ? null : (d) => _dragOffset.value += d.delta.dx,
        onHorizontalDragEnd:
            horizontalPages ? null : (d) => _onDragEnd(d, post),
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) {
            final progress = (offset.abs() / 400).clamp(0.0, 1.0);
            return Container(
              color: Colors.black.withOpacity(1.0 - 0.9 * progress),
              child: Transform.translate(
                offset: horizontalPages ? Offset(0, offset) : Offset(offset, 0),
                child: Transform.scale(
                  scale: 1.0 - 0.12 * progress,
                  child: child,
                ),
              ),
            );
          },
          child: PageView.builder(
            scrollDirection: ref.watch(settingsProvider).viewerSwipeMode
                ? Axis.horizontal
                : Axis.vertical,
            controller: _pageController,
            itemCount: widget.posts.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _resetZoom();
              _trackHistory(widget.posts[index]);
            },
            itemBuilder: (context, index) {
              final p = widget.posts[index];
              final url = mediaUrlOf(p);
              final isVideo = isVideoPost(p);

              if (isVideo) {
                return Center(
                  child: Hero(
                    tag: 'post_${p.serverId}_${p.id}',
                    child: VideoViewer(url: url),
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  if (ref.read(settingsProvider).tapAction == 'detail') {
                    _showDetails(context, p);
                  }
                },
                child: InteractiveViewer(
                  transformationController: _zoomController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: Hero(
                      tag: 'post_${p.serverId}_${p.id}',
                      child: ExtendedImage.network(
                        url,
                        fit: BoxFit.contain,
                        cache: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.loading) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            );
                          }
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white54, size: 48),
                            );
                          }
                          return state.completedWidget;
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 长按：按 longPressAction 设置分发。
  /// 幻灯片不再占用长按，改由 AppBar 按钮触发。
  void _onLongPress(PostSummary post) {
    switch (ref.read(settingsProvider).longPressAction) {
      case 'fav':
        _toggleFavorite(post);
      case 'none':
        break;
      default:
        // 未知值退化为无操作，不做猜测性行为
        break;
    }
  }

  /// 双击：按 doubleTapAction 设置分发（缩放 / 收藏）。
  void _onDoubleTap(PostSummary post) {
    switch (ref.read(settingsProvider).doubleTapAction) {
      case 'zoom':
        _toggleZoom();
      case 'fav':
        _toggleFavorite(post);
      default:
        break;
    }
  }

  /// 双击缩放：在 1x 与 2.5x 之间切换，带动画。
  void _toggleZoom() {
    final target =
        _zoomed ? Matrix4.identity() : (Matrix4.identity()..scale(2.5));
    _zoomed = !_zoomed;
    _zoomController.value = target;
  }

  /// 翻页后复位缩放：否则新一页会继承上一页的放大倍率。
  void _resetZoom() {
    if (!_zoomed && _zoomController.value == Matrix4.identity()) return;
    _zoomed = false;
    _zoomController.value = Matrix4.identity();
  }

  /// 切换收藏。[notify] 为 true 时弹 snackbar 确认——手势触发时用，
  /// 因为手势没有像按钮图标那样明显的视觉反馈。
  Future<void> _toggleFavorite(PostSummary post, {bool notify = true}) async {
    final repo = ref.read(userFavoritesRepoProvider);
    await repo.toggle(post.toPost());
    ref.invalidate(userFavoritesRepoProvider);
    if (!notify || !mounted) return;
    final nowFav = repo.isFavorite(post.id, serverId: post.serverId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(nowFav ? T.addedToFavoritesShort : T.removedFromFavorites),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onDragEnd(DragEndDetails details, PostSummary post) {
    final offset = _dragOffset.value;
    final velocity = details.primaryVelocity ?? 0;
    // 下滑动作按设置分发。纵向翻页模式下纵轴被 PageView 占用，
    // 此时该设置不生效——这是翻页轴的固有限制，不是 bug，
    // 但必须让用户知道，而不是静默忽略。
    if (velocity > 900 &&
        offset.abs() < _dismissThreshold &&
        ref.read(settingsProvider).swipeDownAction == 'detail') {
      _springBack();
      _showDetails(context, post);
      return;
    }
    // 位移过阈值或甩速足够：顺势关闭
    if (offset.abs() > _dismissThreshold || velocity.abs() > 1200) {
      Navigator.of(context).pop();
      return;
    }
    _springBack();
  }

  void _springBack() {
    if (_springListener != null && _springAnim != null) {
      _springAnim!.removeListener(_springListener!);
    }
    _springAnim = Tween(begin: _dragOffset.value, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    _springListener = () => _dragOffset.value = _springAnim!.value;
    _springAnim!.addListener(_springListener!);
    _springController.forward(from: 0);
  }

  void _share(PostSummary post) {
    final postUrl = permalinkOf(post);
    if (postUrl.isEmpty) return;
    Share.share(postUrl);
  }

  Future<void> _download(PostSummary post) async {
    final settings = ref.read(settingsProvider);
    // 进度图标查的是同一个 downloadUrlOf，两者天然对齐。
    final url = downloadUrlOf(
      post,
      preferSample: settings.downloadQuality == 'sample',
    );
    if (url.isEmpty) return;

    final progressNotifier = ref.read(downloadProgressProvider.notifier);
    progressNotifier.start(url, post.id);
    setState(() => _saving = true);

    final result = await ImageDownloader.downloadImage(
      url,
      postId: post.id,
      namespace: post.serverId,
      width: post.width,
      height: post.height,
      onProgress: (p) => progressNotifier.update(url, p),
      downloadPath: settings.downloadPath,
    );
    if (mounted) {
      setState(() => _saving = false);
    }

    if (result.success) {
      progressNotifier.complete(url);
    } else {
      progressNotifier.fail(url, result.error ?? '');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? T.savedToGallery : T.downloadFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDetails(BuildContext context, PostSummary post) {
    context.push('/post/${post.id}/detail', extra: post);
  }
}

class _DownloadProgressIcon extends ConsumerWidget {
  const _DownloadProgressIcon({required this.post});
  final PostSummary post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final url = downloadUrlOf(
      post,
      preferSample: settings.downloadQuality == 'sample',
    );
    final p = ref
        .watch(downloadProgressProvider)
        .where((d) => d.url == url)
        .firstOrNull;
    return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            value: (p?.progress ?? 0) > 0 ? p!.progress : null,
            strokeWidth: 2,
            color: Colors.white));
  }
}
