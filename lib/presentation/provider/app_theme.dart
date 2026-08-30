import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  midnight,
}

final appThemeModeProvider = StateProvider<AppThemeMode>((ref) {
  return AppThemeMode.system;
});

class AppTheme {
  static ThemeData light({Color accentColor = const Color(0xFF951EE5)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData dark({Color accentColor = const Color(0xFF951EE5)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData midnight({Color accentColor = const Color(0xFF951EE5)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF121212),
      surfaceContainerLow: const Color(0xFF1A1A1A),
      surfaceContainer: const Color(0xFF1E1E1E),
      surfaceContainerHigh: const Color(0xFF252525),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
    );
    return dark(accentColor: accentColor).copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    // 系统栏图标亮度跟随主题：浅色主题用深色图标，深色主题用浅色图标，
    // 修复浅色模式下状态栏白色图标不可见的问题。
    final dark = colorScheme.brightness == Brightness.dark;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        // 滚动时不做表面着色，保持与午夜主题一致的纯平面观感
        scrolledUnderElevation: 0,
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
      ),
      // 按键统一胶囊形：与液态玻璃圆角语言一致，触控高度不低于 44dp
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(48, 40),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
