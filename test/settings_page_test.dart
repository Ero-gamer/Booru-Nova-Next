import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/screens/settings/settings_page.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 设置页改成"每项一块玻璃"之后的冒烟测试。
///
/// 玻璃卡片比 ListTile 高得多，又放进 ListView，最容易出的问题是布局溢出
/// （debug 下会抛异常）；同时确认每个条目仍然整块可点、路由不变。
void main() {
  testWidgets('设置页玻璃卡片：正常渲染、无溢出、点条目能跳转', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var pushed = '';
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        for (final entry in [
          '/settings/appearance',
          '/settings/language',
          '/settings/viewer',
        ])
          GoRoute(
            path: entry,
            builder: (_, __) {
              pushed = entry;
              return const Scaffold(body: SizedBox());
            },
          ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // GlassContainer 会读设置（玻璃强度），真实 Notifier 依赖 Hive，
          // 测试里给一份常量设置。
          settingsProvider.overrideWith(_FakeSettings.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // 分组标题与条目都在
    expect(find.byType(SectionHeader), findsWidgets);
    expect(find.text(T.appearance), findsOneWidget);
    expect(find.text(T.appearanceSub), findsOneWidget);

    // 布局无异常（溢出、不可见的 RenderFlex 等都会在这里暴露）
    expect(tester.takeException(), isNull);

    // 条目整块可点（玻璃卡片本身是热区，不是只有文字）
    await tester.tap(find.text(T.appearance));
    await tester.pumpAndSettle();
    expect(pushed, '/settings/appearance');
  });
}

/// 设置 Provider 的常量替身（玻璃强度等读它）。
class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}
