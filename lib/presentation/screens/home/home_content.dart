import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/foundation/util/batch_ops.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/batch_selection.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/screens/home/search/search_bar.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/timeline/timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

String _friendlyError(String raw) {
  if (raw.contains('connection timeout') ||
      raw.contains('Connection timeout') ||
      raw.contains('connectionTimeout')) {
    return '连接超时，请检查网络或尝试使用 Hosts 功能';
  }
  if (raw.contains('receiveTimeout') || raw.contains('Receive timeout')) {
    return '服务器响应超时，请稍后重试';
  }
  if (raw.contains('Connection refused')) {
    return '连接被拒绝，请检查服务器地址是否正确';
  }
  if (raw.contains('Failed host lookup') ||
      raw.contains('No address associated with hostname')) {
    return '域名解析失败，请检查网络或服务器地址';
  }
  if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE')) {
    return '安全连接失败（证书校验未通过），请检查系统时间或网络环境';
  }
  if (RegExp(r'status (code )?of 403').hasMatch(raw)) {
    return '访问被拒绝（403），可能需要登录或 API 密钥';
  }
  if (RegExp(r'status (code )?of 404').hasMatch(raw)) {
    return '资源不存在（404），服务器地址可能已变更';
  }
  if (RegExp(r'status (code )?of 429').hasMatch(raw)) {
    return '请求过于频繁（429），请稍后再试';
  }
  if (RegExp(r'status (code )?of 5\d\d').hasMatch(raw)) {
    return '服务器内部错误（5xx），请稍后再试';
  }
  if (raw.contains('SocketException')) {
    return '网络异常，请检查网络连接';
  }
  if (raw.contains('XML') || raw.contains('parser') || raw.contains('json')) {
    return '服务器返回数据异常，可能不是有效的 Booru 站点';
  }
  final lines = raw.split('\n');
  return lines.length > 2 ? '${lines[0]}\n${lines[1]}' : raw;
}

class HomeContent extends ConsumerStatefulWidget {
  const HomeContent({super.key, this.favicon});

  final Widget? favicon;

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  bool _batchDownloading = false;
  String? _batchProgress;
  bool _searchCollapsed = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final collapsed = pos.pixels > 60;
    if (collapsed != _searchCollapsed) {
      setState(() => _searchCollapsed = collapsed);
    }
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(booruPageStateProvider.notifier).loadMore();
    }
  }

  void _checkFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final pageState = ref.read(booruPageStateProvider);
      if (pageState.isLoading || !pageState.hasMore) return;
      if (pos.maxScrollExtent <= pos.viewportDimension + 100) {
        ref.read(booruPageStateProvider.notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 切换站点后滚动回顶，避免停留在旧内容中间
    ref.listen<String?>(
      booruPageStateProvider.select((s) => s.serverId),
      (prev, next) {
        if (prev != next && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
    );
    final pageState = ref.watch(booruPageStateProvider);
    final currentQuery = ref.read(booruPageStateProvider.notifier).currentQuery;
    final gridCols = ref.watch(gridColumnsProvider);
    final selectedIds = ref.watch(batchSelectionProvider);
    final selectionNotifier = ref.read(batchSelectionProvider.notifier);
    final isSelectionMode = selectedIds.isNotEmpty;
    final blockedTags = ref.watch(tagsBlockerStateProvider);
    final blockedNames = blockedTags.values.map((t) => t.name).toSet();
    final filteredPosts = pageState.posts
        .where((p) => !p.tags.any(blockedNames.contains))
        .toList();

    if (!pageState.isLoading && pageState.hasMore && filteredPosts.isNotEmpty) {
      _checkFillViewport();
    }

    // Stack 布局：瀑布流铺满全屏，玻璃搜索栏悬浮在内容上方
    return Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
                  onRefresh: () async {
                    selectionNotifier.clear();
                    await ref.read(booruPageStateProvider.notifier).refresh();
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (isSelectionMode)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.checklist,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  '${selectedIds.length} ${T.selected}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    selectionNotifier
                                        .selectAll(filteredPosts.map((p) => p.id));
                                  },
                                  child: Text(T.selectAll),
                                ),
                                TextButton(
                                  onPressed: selectionNotifier.clear,
                                  child: Text(T.clear),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (pageState.isLoading && filteredPosts.isEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (filteredPosts.isEmpty && pageState.error != null)
                        SliverFillRemaining(
                          child: EmptyState(
                            icon: Icons.cloud_off,
                            title: T.somethingWentWrong,
                            hint: _friendlyError(pageState.error!),
                            action: OutlinedButton.icon(
                              onPressed: () =>
                                  ref.read(booruPageStateProvider.notifier).refresh(),
                              icon: const Icon(Icons.refresh),
                              label: Text(T.retry),
                            ),
                          ),
                        )
                      else if (filteredPosts.isEmpty)
                        SliverFillRemaining(
                          child: EmptyState(
                            icon: Icons.image_search,
                            title: T.noSearchResults,
                            hint: T.tryDifferentSearch,
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                            child: Text('${filteredPosts.length} ${T.results}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                        ),
                        SliverPadding(
                          // 底部留白让最后一排内容能滚出悬浮玻璃栏
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 96),
                            sliver: Timeline(
                              key: ValueKey('grid_$gridCols'),
                              crossAxisCount: gridCols,
                              posts: filteredPosts,
                              enablePeekPreview: !isSelectionMode,
                              onFavorite: (index) {
                                final post = filteredPosts[index];
                                final repo = ref.read(userFavoritesRepoProvider);
                                repo.toggle(BooruPost(
                                  id: post.id, serverId: post.serverId, thumbnailUrl: post.thumbnailUrl,
                                  sampleUrl: post.sampleUrl, originalUrl: post.originalUrl,
                                  tags: post.tags, tagGeneral: post.tagGeneral,
                                  tagArtist: post.tagArtist, tagCharacter: post.tagCharacter,
                                  tagCopyright: post.tagCopyright, tagMeta: post.tagMeta,
                                  aspectRatio: post.aspectRatio, width: post.width,
                                  height: post.height, rating: post.rating, score: post.score,
                                  source: post.source, postUrl: post.postUrl,
                                ));
                                ref.invalidate(userFavoritesRepoProvider);
                              },
                            isLoading: pageState.isLoading,
                            selectionMode: isSelectionMode,
                            selectedIds: selectedIds,
                            onPostTap: (index) {
                              context.push('/post/${filteredPosts[index].id}',
                                  extra: <String, dynamic>{
                                    'posts': filteredPosts,
                                    'initialIndex': index,
                                  });
                            },
                            onLongPress: (index) {
                              selectionNotifier.toggle(filteredPosts[index].id);
                            },
                            onSelectionToggle: (index) {
                              selectionNotifier.toggle(filteredPosts[index].id);
                            },
                          ),
                        ),
                        if (pageState.isLoading)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
        // 底部悬浮玻璃搜索栏：内容从玻璃下方滚过，模糊才有实际效果
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: GlassContainer(
            child: HomeSearchBar(
          leading: widget.favicon,
          collapsed: _searchCollapsed,
          currentQuery: currentQuery,
          onScrollToTop: () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut);
            }
          },
          hintText: T.searchHint,
          onSubmitted: (query) {
            selectionNotifier.clear();
            ref.read(booruPageStateProvider.notifier).search(query);
          },
            ),
          ),
        ),
        if (isSelectionMode)
          Positioned(
            left: 12,
            right: 12,
            bottom: 84,
            child: GlassContainer(
              borderRadius: BorderRadius.circular(20),
              child: _BatchActionBar(
                selectedIds: selectedIds,
                posts: filteredPosts,
                isDownloading: _batchDownloading,
                progress: _batchProgress,
                onDownload: () => _batchDownload(filteredPosts, selectedIds),
                onFavorite: () => _batchFavorite(context, filteredPosts, selectedIds),
                onShare: () => _batchShare(filteredPosts, selectedIds),
                onClear: selectionNotifier.clear,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _batchDownload(
      List<PostSummary> posts, Set<String> selectedIds) async {
    final selected = posts.where((p) => selectedIds.contains(p.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _batchDownloading = true);
    final urls = selected
        .map((p) =>
            p.originalUrl.isNotEmpty ? p.originalUrl : p.sampleUrl)
        .toList();
    final ids = selected.map((p) => p.id).toList();

    final downloadPath = ref.read(settingsProvider).downloadPath;
    final result = await BatchOps.downloadAll(
      urls,
      ids,
      downloadPath: downloadPath,
      onItemProgress: (done, total) {
        if (mounted && _batchDownloading) {
          setState(() => _batchProgress = '$done/$total');
        }
      },
    );
    if (mounted) {
      setState(() {
        _batchDownloading = false;
        _batchProgress = null;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${T.downloadedCount} ${result.successCount}/${result.items.length} ${T.ofImages}',
          ),
        ),
      );
    }
  }

  Future<void> _batchFavorite(
      BuildContext context, List<PostSummary> posts, Set<String> selectedIds) async {
    final selected = posts.where((p) => selectedIds.contains(p.id)).toList();
    if (selected.isEmpty) return;

    final repo = ref.read(userFavoritesRepoProvider);
    for (final post in selected) {
      if (!repo.isFavorite(post.id, serverId: post.serverId)) {
        await repo.toggle(BooruPost(
          id: post.id,
          serverId: post.serverId,
          thumbnailUrl: post.thumbnailUrl,
          sampleUrl: post.sampleUrl,
          originalUrl: post.originalUrl,
          tags: post.tags,
          tagGeneral: post.tagGeneral,
          tagArtist: post.tagArtist,
          tagCharacter: post.tagCharacter,
          tagCopyright: post.tagCopyright,
          tagMeta: post.tagMeta,
          aspectRatio: post.aspectRatio,
          width: post.width,
          height: post.height,
          rating: post.rating,
          score: post.score,
          source: post.source,
          postUrl: post.postUrl,
        ));
      }
    }
    ref.invalidate(userFavoritesRepoProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${T.addedToFavorites} ${selected.length}')),
    );
  }

  void _batchShare(
      List<PostSummary> posts, Set<String> selectedIds) {
    final selected = posts.where((p) => selectedIds.contains(p.id)).toList();
    if (selected.isEmpty) return;

    final urls = selected
        .map((p) => p.postUrl ?? p.originalUrl)
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty) return;

    Share.share(urls.join('\n'));
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedIds,
    required this.posts,
    required this.isDownloading,
    required this.onDownload,
    required this.onFavorite,
    required this.onShare,
    required this.onClear,
    this.progress,
  });

  final Set<String> selectedIds;
  final List<PostSummary> posts;
  final bool isDownloading;
  final String? progress;
  final VoidCallback onDownload;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // 外层由 GlassContainer 提供玻璃质感，这里只负责布局
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              tooltip: T.downloadSelected,
              onPressed: isDownloading ? null : onDownload,
            ),
            if (isDownloading && progress != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(progress!,
                    style: const TextStyle(fontSize: 13)),
              ),
            IconButton(
              icon: const Icon(Icons.favorite_outline),
              tooltip: T.favoriteSelected,
              onPressed: onFavorite,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: T.shareSelected,
              onPressed: onShare,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: T.clearSelection,
              onPressed: onClear,
            ),
          ],
      ),
    );
  }
}
