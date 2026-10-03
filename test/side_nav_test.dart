import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/glass.dart';
import 'package:boorunova/presentation/widgets/common/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只关心「减少动画」这一个开关，所以不去初始化 Hive。
class _TestSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// 侧栏面板的测试外壳。
///
/// 头图底图固定注入纯色块：默认的 [RandomCoverArt] 会真的发网络请求，
/// 测试里必然失败并触发换源重试，断言会变成跟网络时序赛跑。
Widget _harness(List<List<SideNavItem>> groups) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith(_TestSettings.new)],
    child: MaterialApp(
      home: Scaffold(
        body: SideNavPanel(
          header: const Text('BooruNova'),
          groups: groups,
          artwork: const ColoredBox(color: Colors.blueGrey),
        ),
      ),
    ),
  );
}

SideNavItem _item(String label, {List<String>? tapped}) => SideNavItem(
      icon: Icons.circle_outlined,
      label: label,
      onTap: () => tapped?.add(label),
    );

void main() {
  testWidgets('每个菜单项各自包一块玻璃，而不是共用列表背景', (tester) async {
    await tester.pumpWidget(_harness([
      [_item('收藏'), _item('下载'), _item('历史')],
      [_item('服务器'), _item('黑名单')],
      [_item('设置')],
    ]));

    expect(find.byType(GlassNavTile), findsNWidgets(6));
    // 每项恰好一块玻璃：多一块说明又有别的地方套了玻璃，
    // 少一块说明某一项退回了「跟面板糊在一起」。
    expect(find.byType(GlassContainer), findsNWidgets(6));
    // 原来的实现靠 Divider 分组，现在独立玻璃块之间不该再有分割线。
    expect(find.byType(Divider), findsNothing);

    for (final label in ['收藏', '下载', '历史', '服务器', '黑名单', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('相邻两项的玻璃之间有空隙，视觉上互相独立', (tester) async {
    await tester.pumpWidget(_harness([
      [_item('收藏'), _item('下载')],
    ]));

    final glasses = find.byType(GlassContainer);
    final first = tester.getRect(glasses.at(0));
    final second = tester.getRect(glasses.at(1));

    expect(second.top, greaterThan(first.bottom));
    // 左右也要留边：贴着抽屉边缘就不像浮在上面的玻璃了。
    expect(first.left, greaterThan(0));
    expect(first.width, lessThan(tester.getSize(find.byType(SideNavPanel)).width));
  });

  testWidgets('分组之间留白大于组内间距', (tester) async {
    await tester.pumpWidget(_harness([
      [_item('收藏'), _item('下载')],
      [_item('服务器')],
    ]));

    final glasses = find.byType(GlassContainer);
    final insideGroup = tester.getRect(glasses.at(1)).top -
        tester.getRect(glasses.at(0)).bottom;
    final betweenGroups = tester.getRect(glasses.at(2)).top -
        tester.getRect(glasses.at(1)).bottom;

    expect(betweenGroups, greaterThan(insideGroup));
  });

  testWidgets('点击某一项只触发它自己的回调', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(_harness([
      [_item('收藏', tapped: tapped), _item('下载', tapped: tapped)],
    ]));

    await tester.tap(find.text('下载'));
    await tester.pump();

    expect(tapped, ['下载']);
  });

  testWidgets('头图承载内容，且不参与底图的下边缘渐隐', (tester) async {
    await tester.pumpWidget(_harness([
      [_item('收藏')],
    ]));

    expect(find.byType(SideNavHeader), findsOneWidget);
    expect(find.text('BooruNova'), findsOneWidget);

    // 内容层必须在 ShaderMask 之外：否则标题会跟着图片一起在下边缘淡掉。
    final title = find.text('BooruNova');
    expect(
      find.ancestor(of: title, matching: find.byType(ShaderMask)),
      findsNothing,
    );
  });
}
