import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/app_theme.dart';
import 'package:boorunova/presentation/router.dart';
import 'package:boorunova/presentation/widgets/common/brand_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooruNova extends ConsumerStatefulWidget {
  const BooruNova({super.key});

  @override
  ConsumerState<BooruNova> createState() => _BooruNovaState();
}

class _BooruNovaState extends ConsumerState<BooruNova> {
  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      ref.read(appThemeModeProvider.notifier).state = settings.themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
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
