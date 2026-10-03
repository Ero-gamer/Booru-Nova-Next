import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

class HiveSetup {
  static const String serversBoxName = 'servers';
  static const String settingsBoxName = 'settings';

  static String _dirPath = '';

  /// 本次启动是否从损坏的 box 里恢复过。UI 可据此提示用户「有本地数据已损坏
  /// 并隔离」，而不是让用户以为数据凭空消失。
  static bool recoveredFromCorruption = false;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _dirPath = dir.path;
    Hive.init(_dirPath);
    await _openBoxes();
  }

  static Future<void> _openBoxes() async {
    // 串行打开：并行打开时一个损坏会让另一个半开，Hive 的状态更难收拾。
    await _openBox(serversBoxName);
    await _openBox(settingsBoxName);
  }

  /// 打开单个 box；整体损坏时把文件**改名留证**后重建空 box。
  ///
  /// 此前这里是裸 `openBox`：box 一旦损坏，启动阶段直接抛 HiveError，
  /// `main` 的 `await HiveSetup.init()` 又没有 try/catch，应用永远停在白屏，
  /// 用户只能「清除应用数据」——那等于把还能人工找回的文件一起判死刑。
  static Future<void> _openBox(String name) async {
    try {
      // crashRecovery 让 Hive 尽量跳过损坏的帧，而不是整个 box 打不开。
      await Hive.openBox(name, crashRecovery: true);
      return;
    } catch (_) {
      // 先关掉可能半开的实例，否则重建时会报「box already open」
      try {
        await Hive.close();
      } catch (_) {}
      _quarantine(name);
      recoveredFromCorruption = true;
      // 重建空 box：应用能起来，比白屏强；原文件以 .corrupt.<ts> 保留在原地。
      await Hive.openBox(name);
    }
  }

  static void _quarantine(String name) {
    if (_dirPath.isEmpty) return;
    final file = File('$_dirPath${Platform.pathSeparator}$name.hive');
    if (!file.existsSync()) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    try {
      file.renameSync('${file.path}.corrupt.$stamp');
    } catch (_) {
      // 改名失败（权限/被占用）也不能让启动流程崩掉
    }
  }

  /// 把内存里的待写数据落盘。App 进入后台时调用，减少进程被杀导致丢数据。
  static Future<void> flush() async {
    for (final name in const [serversBoxName, settingsBoxName]) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        await Hive.box(name).flush();
      } catch (_) {
        // flush 失败不影响前台使用
      }
    }
  }

  static Box get serversBox => Hive.box(serversBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}
