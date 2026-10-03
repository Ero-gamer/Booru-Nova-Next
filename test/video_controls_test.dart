import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/screens/home/search/search_bar.dart';
import 'package:boorunova/presentation/widgets/media/video_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 视频播放器与搜索栏的交互回归。
///
/// 这两处都是「看起来能用、实际点不到」的典型：
/// 播放器此前只有一条极细的进度指示线（拖不住、也没有时间显示），
/// 搜索栏此前只有文字字形区域命中——用户反映"必须点放大镜才能进搜索"。
void main() {
  group('播放时间显示', () {
    test('分秒与跨小时', () {
      expect(formatVideoDuration(Duration.zero), '0:00');
      expect(formatVideoDuration(const Duration(seconds: 5)), '0:05');
      expect(formatVideoDuration(const Duration(seconds: 59)), '0:59');
      expect(formatVideoDuration(const Duration(seconds: 60)), '1:00');
      expect(formatVideoDuration(const Duration(minutes: 12, seconds: 34)),
          '12:34');
      expect(
          formatVideoDuration(
              const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
      // 极端值不能崩、不能出现负号
      expect(formatVideoDuration(const Duration(seconds: -5)), '0:00');
    });
  });

  group('搜索栏整条可点', () {
    /// 造一个「点进 /search 就置位」的路由环境，并返回置位标记。
    ({GoRouter router, ValueNotifier<bool> opened}) harness() {
      final opened = ValueNotifier(false);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: HomeSearchBar(
                  hintText: 'hint',
                  onSubmitted: (_) {},
                  currentQuery: '',
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (_, __) {
              opened.value = true;
              return const Scaffold(body: SizedBox());
            },
          ),
        ],
      );
      return (router: router, opened: opened);
    }

    Future<void> pumpBar(WidgetTester tester, GoRouter router) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // 真实 SettingsNotifier 依赖 Hive（测试里没有初始化），
            // 这里给一份常量设置：搜索栏只读 gridColumns。
            settingsProvider.overrideWith(_FakeSettings.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('点放大镜可以进入搜索页（基线）', (tester) async {
      final h = harness();
      await pumpBar(tester, h.router);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(h.opened.value, isTrue);
    });

    testWidgets('点搜索栏里文字以外的空白处也能进入搜索页', (tester) async {
      final h = harness();
      await pumpBar(tester, h.router);

      // 修复前 GestureDetector 没有 opaque 行为，命中测试只覆盖文字字形，
      // 文字左右的空白点不到 —— 正是"必须点放大镜"的成因。
      final textRect = tester.getRect(find.text(T.tapToSearch));
      await tester.tapAt(Offset(
        (textRect.right + 160).clamp(0.0, 700.0),
        textRect.center.dy,
      ));
      await tester.pumpAndSettle();

      expect(h.opened.value, isTrue, reason: '点搜索栏空白处应当进入搜索页');
    });
  });
}

/// 设置 Provider 的常量替身：搜索栏只读 gridColumns，其余用默认值。
class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}
