import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/screens/artists/artists_page.dart';
import 'package:boorunova/presentation/screens/blacklist/blacklist_page.dart';
import 'package:boorunova/presentation/screens/downloads/downloads_page.dart';
import 'package:boorunova/presentation/screens/explore/explore_page.dart';
import 'package:boorunova/presentation/screens/favorites/favorites_page.dart';
import 'package:boorunova/presentation/screens/forum/forum_page.dart';
import 'package:boorunova/presentation/screens/history/history_page.dart';
import 'package:boorunova/presentation/screens/history/search_history_page.dart';
import 'package:boorunova/presentation/screens/home/home_page.dart';
import 'package:boorunova/presentation/screens/onboarding/onboarding_page.dart';
import 'package:boorunova/presentation/screens/pools/pool_detail_page.dart';
import 'package:boorunova/presentation/screens/pools/pools_page.dart';
import 'package:boorunova/presentation/screens/post/post_detail_page.dart';
import 'package:boorunova/presentation/screens/post/post_viewer.dart';
import 'package:boorunova/presentation/screens/search/search_page.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:boorunova/presentation/screens/server/server_editor_page.dart';
import 'package:boorunova/presentation/screens/server/server_page.dart';
import 'package:boorunova/presentation/screens/server/server_probe_page.dart';
import 'package:boorunova/presentation/screens/settings/about_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/appearance_page.dart';
import 'package:boorunova/presentation/screens/settings/data_backup_page.dart';
import 'package:boorunova/presentation/screens/settings/data_storage_page.dart';
import 'package:boorunova/presentation/screens/settings/download_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/gestures_page.dart';
import 'package:boorunova/presentation/screens/settings/hosts_page.dart';
import 'package:boorunova/presentation/screens/settings/language_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/privacy_page.dart';
import 'package:boorunova/presentation/screens/settings/search_settings_page.dart';
import 'package:boorunova/presentation/screens/settings/settings_page.dart';
import 'package:boorunova/presentation/screens/settings/viewer_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Page<T> _slidePage<T>(Widget child, {bool reduceAnimations = false}) {
  final duration = reduceAnimations ? Duration.zero : const Duration(milliseconds: 300);
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        )),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    // 首次启动（未完成引导 且 尚无任何站点）强制进入引导页。
    // 双条件避免老用户升级时（有站点、无 onboardingComplete 标记）被强制重走。
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final hasServers = ref.read(userServerRepoProvider).count > 0;
      final needsOnboarding =
          !settings.onboardingComplete && !hasServers;
      final onOnboarding = state.uri.path == '/onboarding';
      if (needsOnboarding && !onOnboarding) return '/onboarding';
      if (!needsOnboarding && onOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => _slidePage(const HomePage()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => _slidePage(const OnboardingPage()),
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        pageBuilder: (context, state) => _slidePage(const FavoritesPage()),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        pageBuilder: (context, state) => _slidePage(const HistoryPage()),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        pageBuilder: (context, state) => _slidePage(const DownloadsPage()),
      ),
      GoRoute(
        path: '/search-history',
        name: 'search-history',
        pageBuilder: (context, state) => _slidePage(const SearchHistoryPage()),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final initialQuery =
              extra is Map ? (extra['initialQuery'] as String? ?? '') : '';
          return _slidePage(SearchPage(initialQuery: initialQuery));
        },
      ),
      GoRoute(
        path: '/explore',
        name: 'explore',
        pageBuilder: (context, state) => _slidePage(const ExplorePage()),
      ),
      GoRoute(
        path: '/pools',
        name: 'pools',
        pageBuilder: (context, state) => _slidePage(const PoolsPage()),
      ),
      GoRoute(
        path: '/pools/:id',
        name: 'pool-detail',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final name = extra is Map ? (extra['name'] as String? ?? '') : '';
          return _slidePage(PoolDetailPage(
            poolId: state.pathParameters['id']!,
            poolName: name,
          ));
        },
      ),
      GoRoute(
        path: '/blacklist',
        name: 'blacklist',
        pageBuilder: (context, state) => _slidePage(const BlacklistPage()),
      ),
      GoRoute(
        path: '/forum',
        name: 'forum',
        pageBuilder: (context, state) => _slidePage(const ForumPage()),
      ),
      GoRoute(
        path: '/artists',
        name: 'artists',
        pageBuilder: (context, state) => _slidePage(const ArtistsPage()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => _slidePage(const SettingsPage()),
        routes: [
          GoRoute(
            path: 'hosts',
            name: 'settings-hosts',
            pageBuilder: (context, state) => _slidePage(const HostsPage()),
          ),
          GoRoute(
            path: 'viewer',
            name: 'settings-viewer',
            pageBuilder: (context, state) => _slidePage(const ViewerSettingsPage()),
          ),
          GoRoute(
            path: 'appearance',
            name: 'settings-appearance',
            pageBuilder: (context, state) => _slidePage(const AppearanceSettingsPage()),
          ),
          GoRoute(
            path: 'language',
            name: 'settings-language',
            pageBuilder: (context, state) => _slidePage(const LanguageSettingsPage()),
          ),
          GoRoute(
            path: 'gestures',
            name: 'settings-gestures',
            pageBuilder: (context, state) => _slidePage(const GesturesPage()),
          ),
          GoRoute(
            path: 'search',
            name: 'settings-search',
            pageBuilder: (context, state) => _slidePage(const SearchSettingsPage()),
          ),
          GoRoute(
            path: 'download',
            name: 'settings-download',
            pageBuilder: (context, state) => _slidePage(const DownloadSettingsPage()),
          ),
          GoRoute(
            path: 'data',
            name: 'settings-data',
            pageBuilder: (context, state) => _slidePage(const DataStoragePage()),
          ),
          GoRoute(
            path: 'backup',
            name: 'settings-backup',
            pageBuilder: (context, state) => _slidePage(const DataBackupPage()),
          ),
          GoRoute(
            path: 'privacy',
            name: 'settings-privacy',
            pageBuilder: (context, state) => _slidePage(const PrivacyPage()),
          ),
          GoRoute(
            path: 'about',
            name: 'settings-about',
            pageBuilder: (context, state) => _slidePage(const AboutSettingsPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/servers',
        name: 'servers',
        pageBuilder: (context, state) => _slidePage(const ServerPage()),
        routes: [
          GoRoute(
            path: 'editor',
            name: 'servers-editor',
            pageBuilder: (context, state) {
              final extra = state.extra;
              if (extra is Map) {
                return _slidePage(ServerEditorPage(
                  serverId: extra['serverId'] as String?,
                  template: extra['template'] as BooruSiteTemplate?,
                  initialUrl: extra['initialUrl'] as String?,
                  initialName: extra['initialName'] as String?,
                  initialType: extra['initialType'] as BooruType?,
                ));
              }
              return _slidePage(const _InvalidRoutePage());
            },
          ),
          GoRoute(
            path: 'scan',
            name: 'servers-scan',
            pageBuilder: (context, state) {
              final extra = state.extra;
              final initialUrl =
                  extra is Map ? (extra['initialUrl'] as String? ?? '') : '';
              return _slidePage(ServerScanPage(initialUrl: initialUrl));
            },
          ),
        ],
      ),
      GoRoute(
        path: '/post/:id',
        name: 'post',
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final posts = extra['posts'];
            final initialIndex = extra['initialIndex'];
            if (posts is List<PostSummary> && initialIndex is int && initialIndex >= 0 && initialIndex < posts.length) {
              return _slidePage(PostViewer(posts: posts, initialIndex: initialIndex));
            }
          }
          return _slidePage(const _InvalidRoutePage());
        },
        routes: [
          GoRoute(
            path: 'detail',
            name: 'post-detail',
            pageBuilder: (context, state) {
              final post = state.extra;
              if (post is PostSummary) {
                return _slidePage(PostDetailPage(post: post));
              }
              return _slidePage(const _InvalidRoutePage());
            },
          ),
        ],
      ),
    ],
  );
});

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('链接无效', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('请从主页重新进入', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('返回主页'),
            ),
          ],
        ),
      ),
    );
  }
}
