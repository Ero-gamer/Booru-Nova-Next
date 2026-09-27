import 'package:boorunova/boorus/engine/booru_repository.dart';
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

/// 底层异常 → 面向用户的提示。
///
/// 全部走 T 而非硬编码中文：这张表在英文界面下同样会被读到。
String _friendlyError(String raw) {
  if (raw == kNoServerSelected) return T.noServerSelected;
  if (raw.contains('connection timeout') ||
      raw.contains('Connection timeout') ||
      raw.contains('connectionTimeout')) {
    return T.errTimeout;
  }
  if (raw.contains('receiveTimeout') || raw.contains('Receive timeout')) {
    return T.errReceiveTimeout;
  }
  if (raw.contains('Connection refused')) {
    return T.errRefused;
  }
  if (raw.contains('Failed host lookup') ||
      raw.contains('No address associated with hostname')) {
    return T.errDns;
  }
  if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE')) {
    return T.errTls;
  }
  if (RegExp(r'status (code )?of 403').hasMatch(raw)) {
    return T.err403;
  }
  if (RegExp(r'status (code )?of 404').hasMatch(raw)) {
    return T.err404;
  }
  if (RegExp(r'status (code )?of 429').hasMatch(raw)) {
    return T.err429;
  }
  if (RegExp(r'status (code )?of 5\d\d').hasMatch(raw)) {
    return T.err5xx;
  }
  if (raw.contains('SocketException')) {
    return T.errNetwork;
  }
  if (raw.contains('XML') || raw.contains('parser') || raw.contains('json')) {
    return T.errBadPayload;
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
    final gridCols = ref.watch(settingsProvider).gridColumns;
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
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              selectionNotifier
                                  .selectAll(filteredPosts.map(postKeyOf));
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
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
                        repo.toggle(post.toPost());
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
                        selectionNotifier
                            .toggle(postKeyOf(filteredPosts[index]));
                      },
                      onSelectionToggle: (index) {
                        selectionNotifier
                            .toggle(postKeyOf(filteredPosts[index]));
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
                  // 翻页失败：内容保留，末尾给出显式重试入口。
                  // 之前这里静默吞掉错误，滚动会无限重试坏掉的请求。
                  if (pageState.pagingFailed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Column(
                          children: [
                            Text(
                              T.loadMoreFailed,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(booruPageStateProvider.notifier)
                                  .retryLoadMore(),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(T.retryLoadMore),
                            ),
                          ],
                        ),
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
                onFavorite: () =>
                    _batchFavorite(context, filteredPosts, selectedIds),
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
    final selected =
        posts.where((p) => selectedIds.contains(postKeyOf(p))).toList();
    if (selected.isEmpty) return;

    setState(() => _batchDownloading = true);
    // 与单个下载（post_viewer._download）共用同一套质量选择逻辑：
    // 设置为 sample 时批量也只取 sample，否则用户设了省流量却被
    // 静默地按原图批量下载。
    final settings = ref.read(settingsProvider);
    final urls = selected
        .map((p) => downloadUrlOf(
              p,
              preferSample: settings.downloadQuality == 'sample',
            ))
        .toList();
    final ids = selected.map((p) => p.id).toList();
    final namespaces = selected.map((p) => p.serverId).toList();

    final downloadPath = settings.downloadPath;
    final result = await BatchOps.downloadAll(
      urls,
      ids,
      namespaces: namespaces,
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

  Future<void> _batchFavorite(BuildContext context, List<PostSummary> posts,
      Set<String> selectedIds) async {
    final selected =
        posts.where((p) => selectedIds.contains(postKeyOf(p))).toList();
    if (selected.isEmpty) return;

    final repo = ref.read(userFavoritesRepoProvider);
    for (final post in selected) {
      if (!repo.isFavorite(post.id, serverId: post.serverId)) {
        await repo.toggle(post.toPost());
      }
    }
    ref.invalidate(userFavoritesRepoProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${T.addedToFavorites} ${selected.length}')),
    );
  }

  void _batchShare(List<PostSummary> posts, Set<String> selectedIds) {
    final selected =
        posts.where((p) => selectedIds.contains(postKeyOf(p))).toList();
    if (selected.isEmpty) return;

    final urls = selected.map(permalinkOf).where((u) => u.isNotEmpty).toList();
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
              child: Text(progress!, style: const TextStyle(fontSize: 13)),
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
