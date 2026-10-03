import 'dart:async';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
import 'package:boorunova/presentation/router.dart';
import 'package:boorunova/presentation/widgets/common/brand_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooruNova extends ConsumerStatefulWidget {
  const BooruNova({super.key, this.bootError});

  /// 启动阶段（打开本地存储）的失败原因。非 null 时只渲染降级页：
  /// 此刻**不能**碰任何 Riverpod provider —— 它们全都要读 Hive，一读就崩。
  final Object? bootError;

  @override
  ConsumerState<BooruNova> createState() => _BooruNovaState();
}

class _BooruNovaState extends ConsumerState<BooruNova>
    with WidgetsBindingObserver {
  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.bootError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      ref.read(appThemeModeProvider.notifier).state = settings.themeMode;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 进后台/被杀前把待写数据落盘：Hive 的写入是异步的，不 flush 的话
    // 进程被回收会丢掉最后几笔（收藏、历史、下载记录）。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(HiveSetup.flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootError = widget.bootError;
    if (bootError != null) return _BootFailureApp(error: bootError);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final settings = ref.watch(settingsProvider);
    final accentColor = Color(settings.accentColor);

    // 同步静态文案语言；locale 作为 key 使语言切换时整树重建，
    // 所有读取 T.xxx 的界面随之刷新。
    // 副作用的取舍：换 key 会重建 go_router 维护的路由 State（如深层编辑页、
    // 引导进度）。为抵消这一点，引导页等需要跨重建保留的状态已提升到
    // Riverpod provider（见 onboarding 状态），并给路由页面提供稳定 key。
    T.setLocale(settings.language);
    final isEn = settings.language.startsWith('en');

    final darkTheme = switch (themeMode) {
      AppThemeMode.midnight || AppThemeMode.system => AppTheme.midnight(accentColor: accentColor),
      _ => AppTheme.dark(accentColor: accentColor),
    };

    // Stack 在 MaterialApp 之外，无 Directionality 祖先，需显式指定
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        MaterialApp.router(
          title: 'BooruNova',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.light(accentColor: accentColor),
          darkTheme: darkTheme,
          themeMode: _resolveThemeMode(themeMode),
          locale: isEn ? const Locale('en', 'US') : const Locale('zh', 'CN'),
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('zh'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
        // 开头动画：原生 splash 后的品牌过渡，播完自动移除
        if (_splashVisible)
          BrandSplash(
            // 依据当前主题判断明暗；BrandSplash 在 MaterialApp 外拿不到 Theme
            dark: _resolveDark(themeMode),
            onFinished: () {
              if (mounted) setState(() => _splashVisible = false);
            },
          ),
      ],
    );
  }

  ThemeMode _resolveThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.midnight:
        return ThemeMode.dark;
    }
  }

  /// BrandSplash 深色判断：显式 dark/midnight 视为深色；system 跟随系统明暗。
  bool _resolveDark(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
      case AppThemeMode.midnight:
        return true;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }
}

/// 本地存储打不开时的降级页。
///
/// 它必须完全独立于 Riverpod 与 Hive —— 这正是它能显示出来的前提。
/// 同时按系统明暗给一套最简主题，避免依赖 settings（那也要读 Hive）。
class _BootFailureApp extends StatelessWidget {
  const _BootFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF951EE5),
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storage_rounded,
                    size: 56, color: scheme.error),
                const SizedBox(height: 16),
                Text(T.bootFailedTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    )),
                const SizedBox(height: 8),
                Text(
                  T.bootFailedHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // 原始错误留给开发者排查，不翻译
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
