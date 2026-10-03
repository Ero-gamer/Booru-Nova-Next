import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/registry.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/screens/home/home_content.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/common/server_favicon.dart';
import 'package:boorunova/presentation/widgets/common/side_nav.dart';
import 'package:boorunova/presentation/widgets/common/site_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  BooruServer? _activeServer;
  final Map<String, BooruRepository> _repoCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultServer();
    });
  }

  void _onServersChanged(List<BooruServer> servers) {
    if (_activeServer != null) {
      // active 服务器被编辑（URL/凭据变化）→ 失效缓存并重建 repo 刷新
      final updated =
          servers.where((s) => s.id == _activeServer!.id).firstOrNull;
      if (updated == null) {
        // active 服务器被删除：清空缓存并切到第一个可用站点
        _repoCache.remove(_activeServer!.id);
        _activeServer = null;
      } else if (_configChanged(updated)) {
        _repoCache.remove(updated.id);
        _activeServer = null;
        _selectServer(updated);
        return;
      } else {
        return;
      }
    }
    if (servers.isEmpty) return;
    final settings = ref.read(settingsProvider);
    BooruServer? target;
    if (settings.defaultServerId != null) {
      target =
          servers.where((s) => s.id == settings.defaultServerId).firstOrNull;
    }
    if (ref.read(booruPageStateProvider.notifier).currentQuery.isEmpty) {
      _selectServer(target ?? servers.first);
    }
  }

  bool _configChanged(BooruServer updated) {
    final cur = _activeServer;
    if (cur == null) return true;
    return cur.baseUrl != updated.baseUrl ||
        cur.type != updated.type ||
        cur.login != updated.login ||
        cur.apiKey != updated.apiKey;
  }

  void _initDefaultServer() {
    final servers = ref.read(userServerRepoProvider).getAll();
    if (servers.isEmpty) return;

    final settings = ref.read(settingsProvider);
    BooruServer? target;
    if (settings.defaultServerId != null) {
      target =
          servers.where((s) => s.id == settings.defaultServerId).firstOrNull;
    }
    if (ref.read(booruPageStateProvider.notifier).currentQuery.isEmpty) {
      _selectServer(target ?? servers.first);
    }
  }

  void _selectServer(BooruServer server) {
    if (server.id == _activeServer?.id) return;
    setState(() => _activeServer = server);
    final registry = ref.read(booruRegistryProvider);
    try {
      final repo = _repoCache[server.id] ??
          registry.createRepository(
            server.type,
            baseUrl: server.baseUrl,
            serverId: server.id,
            login: server.login,
            apiKey: server.apiKey,
          );
      _repoCache[server.id] = repo;
      final notifier = ref.read(booruPageStateProvider.notifier);
      // 有搜索词时也重新加载（保留旧内容），避免显示旧服务器帖子
      notifier.switchServer(repo);
    } catch (e) {
      final template = BooruSiteTemplate.findByType(server.type);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            template != null
                ? '${template.name} 引擎不可用，请更换服务器或修改引擎类型'
                : '引擎不可用：${server.type.value}',
          ),
        ),
      );
    }
  }

  Widget _buildFavicon(String baseUrl) {
    return _serverFavicon(baseUrl, _activeServer!.type, size: 24);
  }

  /// 图集入口是否可用：仅在真正实现了 fetchPools 的引擎上显示。
  ///
  /// 此前是 `bool Function(BooruCapabilities)` 的泛型检查层。删掉其余
  /// 十个零消费的能力字段后，全项目只剩 pools 一个调用点，间接层
  /// 反而让「这个引擎到底支持什么」更难一眼读完。
  bool get _supportsPools {
    final server = _activeServer;
    if (server == null) return false;
    try {
      final engine = ref.read(booruRegistryProvider).get(server.type);
      return engine != null && engine.booru.capabilities.pools;
    } catch (_) {
      return false;
    }
  }

  Widget _serverFavicon(String baseUrl, BooruType type, {double size = 16}) =>
      ServerFavicon(baseUrl: baseUrl, type: type, size: size);

  /// 在给定全局坐标处弹出站点切换菜单。
  ///
  /// 抽成独立方法，让搜索栏 favicon 和端抽屉头两处入口行为完全一致——
  /// 此前端抽屉的入口只有一个空分支和一行 TODO 注释。
  ///
  /// 只有一个站点时给出明确提示并直达服务器管理页，而不是静默返回：
  /// 长按/点击无反应会被用户当成手势失效。
  void _openServerSwitcherAt(BuildContext menuContext, Offset topLeft) {
    final servers = ref.read(userServerRepoProvider).getAll();
    if (servers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.onlyOneServerHint),
          action: SnackBarAction(
            label: T.addServer,
            onPressed: () => context.push('/servers'),
          ),
        ),
      );
      return;
    }

    final screenSize = MediaQuery.of(menuContext).size;
    final items = <PopupMenuEntry<String>>[
      for (final s in servers)
        PopupMenuItem<String>(
          value: s.id,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _serverFavicon(s.baseUrl, s.type, size: 18),
              const SizedBox(width: 8),
              Text(s.name, style: const TextStyle(fontSize: 13)),
              if (s.id == _activeServer?.id) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
    ];

    showMenu<String>(
      context: menuContext,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(topLeft.dx, topLeft.dy, 0, 0),
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height),
      ),
      items: items,
    ).then((id) {
      if (id == null) return;
      _selectServer(servers.firstWhere((s) => s.id == id));
    });
  }

  Widget _faviconWidget() {
    if (_activeServer == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Builder(
        builder: (ctx) => Tooltip(
          message: T.switchServerTip,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              final box = ctx.findRenderObject() as RenderBox?;
              if (box == null) return;
              final origin = box.localToGlobal(Offset.zero);
              _openServerSwitcherAt(
                ctx,
                Offset(origin.dx, origin.dy + box.size.height),
              );
            },
            child: _buildFavicon(_activeServer!.baseUrl),
          ),
        ),
      ),
    );
  }

  /// 关掉抽屉再跳转。侧栏所有入口共用，避免每项都写两行。
  void _goFromDrawer(String location) {
    Navigator.pop(context);
    context.push(location);
  }

  /// 侧栏头图底图：当前站点的随机安全图，点一下进帖子查看器。
  ///
  /// 走 `/post/:id` 而不是详情页：点瀑布流格子和点这里应该是同一个动作
  /// （都是「打开这张图」，进去之后照样能翻到详情页）。
  /// 整批候选一起传进去，查看器里就能左右滑着看这一页随机图。
  Widget _artwork(BuildContext context) {
    return SiteArtwork(
      onTap: (posts, index) {
        Navigator.pop(context);
        context.push(
          '/post/${posts[index].id}',
          extra: <String, dynamic>{'posts': posts, 'initialIndex': index},
        );
      },
    );
  }

  /// 左抽屉头图：品牌图标 + 应用名，白字压在随机头图的深色压暗层上。
  Widget _brandHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.image_search, size: 32, color: Colors.white),
        const SizedBox(height: 6),
        Text(
          'BooruNova',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// 右抽屉头图内容：当前站点 + 点击切换，与搜索栏 favicon 共用同一套菜单。
  ///
  /// 此前这里只有 Navigator.pop + 一行 TODO 注释，按下等于关抽屉。
  Widget _serverHeader(BuildContext context) {
    // 没有活动站点时不要走 _buildFavicon：它对 _activeServer 取非空断言，
    // 而右抽屉在「一个站点都没配好」时也能被滑出来，会直接崩在断言上。
    final server = _activeServer;
    final leading = server == null
        ? const SizedBox(width: 24, height: 24)
        : _serverFavicon(server.baseUrl, server.type, size: 24);

    return Builder(
      builder: (ctx) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(ctx);
          // 抽屉已关闭，原锚点元素随之卸载；用 overlay 重新定位。
          final overlay = Overlay.of(context);
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _openServerSwitcherAt(
            overlay.context,
            box.localToGlobal(const Offset(16, 88)),
          );
        },
        child: Row(
          children: [
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                server?.name ?? 'BooruNova',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.swap_horiz, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(userServerRepoProvider).getAll();
    ref.listen<UserServerRepo>(userServerRepoProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onServersChanged(next.getAll());
      });
    });

    return Scaffold(
      drawer: Drawer(
        // 背景交给 GlassDrawer 的磨砂层；这里透明，让抽屉滑出时透出下层
        backgroundColor: Colors.transparent,
        child: GlassDrawer(
          child: SideNavPanel(
            header: _brandHeader(context),
            artwork: _artwork(context),
            groups: [
              [
                SideNavItem(
                  icon: Icons.favorite_outline,
                  label: T.favorites,
                  onTap: () => _goFromDrawer('/favorites'),
                ),
                SideNavItem(
                  icon: Icons.download_outlined,
                  label: T.downloads,
                  onTap: () => _goFromDrawer('/downloads'),
                ),
                SideNavItem(
                  icon: Icons.history,
                  label: T.history,
                  onTap: () => _goFromDrawer('/history'),
                ),
              ],
              [
                SideNavItem(
                  icon: Icons.dns_outlined,
                  label: T.servers,
                  onTap: () => _goFromDrawer('/servers'),
                ),
                SideNavItem(
                  icon: Icons.block_outlined,
                  label: T.blacklist,
                  onTap: () => _goFromDrawer('/blacklist'),
                ),
              ],
              [
                SideNavItem(
                  icon: Icons.settings_outlined,
                  label: T.settings,
                  onTap: () => _goFromDrawer('/settings'),
                ),
              ],
            ],
          ),
        ),
      ),
      drawerEdgeDragWidth: 40,
      endDrawer: Drawer(
        // 背景交给 GlassDrawer，透明让下层内容在滑出时透出
        backgroundColor: Colors.transparent,
        child: GlassDrawer(
          right: true,
          child: SideNavPanel(
            right: true,
            header: _serverHeader(context),
            artwork: _artwork(context),
            groups: [
              [
                SideNavItem(
                  icon: Icons.explore_outlined,
                  label: T.explore,
                  onTap: () => _goFromDrawer('/explore'),
                ),
                // 图集仅在实际实现了 fetchPools 的引擎（danbooru/e621/moebooru）显示
                if (_supportsPools)
                  SideNavItem(
                    icon: Icons.collections_outlined,
                    label: T.pools,
                    onTap: () => _goFromDrawer('/pools'),
                  ),
              ],
            ],
          ),
        ),
      ),
      appBar: AppBar(
        toolbarHeight: 1,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Builder(
        builder: (ctx) => GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! > 100) {
              Scaffold.of(ctx).openDrawer();
            } else if (details.primaryVelocity! < -100) {
              Scaffold.of(ctx).openEndDrawer();
            }
          },
          child: servers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_search,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(T.noPostsYet,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5))),
                      const SizedBox(height: 8),
                      Text(T.addBooruServer,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.3))),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.push('/servers'),
                        icon: const Icon(Icons.add),
                        label: Text(T.addServer),
                      ),
                    ],
                  ),
                )
              : HomeContent(favicon: _faviconWidget()),
        ),
      ),
    );
  }
}
