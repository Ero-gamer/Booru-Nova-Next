import 'dart:async';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/booru_nova.dart';
import 'package:boorunova/presentation/provider/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局错误出口。此前全项目一个都没有：release 下未捕获异常只留在系统日志，
  // 用户看到的是白屏或闪退，开发者一无所知。这里先保证「不静默」。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('未捕获异步异常: $error\n$stack');
    return true;
  };

  // Hive 是首帧必需的数据，但**不能**让它把应用锁死在启动前：
  // 一旦 box 损坏或磁盘异常，旧的裸 await 会让 runApp 永不执行 —— 永久白屏，
  // 用户只能清除应用数据。这里把失败收起来交给 UI 渲染降级页。
  Object? bootError;
  try {
    await HiveSetup.init();
  } catch (e) {
    bootError = e;
  }

  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: BooruNova(bootError: bootError),
    ),
  );

  // 首帧渲染后再填充版本号（StateProvider 更新会通知监听方，无需 override）
  unawaited(PackageInfo.fromPlatform().then((info) {
    container.read(appVersionProvider.notifier).state = info.version;
  }));

  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]));
}
