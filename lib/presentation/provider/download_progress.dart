import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.url,
    required this.postId,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.error,
  });

  final String url;
  final String postId;
  final double progress;
  final DownloadStatus status;
  final String? error;

  /// [clearError] 用于显式清空错误：`error ?? this.error` 这种写法永远清不掉
  /// 已经写入的错误（BooruPageState 早就用哨兵值修过同一个坑，这里漏了）。
  DownloadProgress copyWith({
    double? progress,
    DownloadStatus? status,
    String? error,
    bool clearError = false,
  }) =>
      DownloadProgress(
        url: url,
        postId: postId,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );
}

enum DownloadStatus { downloading, completed, failed }

final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, List<DownloadProgress>>(
        (ref) {
  return DownloadProgressNotifier();
});

class DownloadProgressNotifier extends StateNotifier<List<DownloadProgress>> {
  DownloadProgressNotifier() : super([]);

  /// 终态条目保留多久后自动消失。`complete` 与 `fail` 都要清：此前只有
  /// 成功会清，失败条目永久堆积（长会话里越攒越多）。
  static const Duration _terminalTtl = Duration(seconds: 3);

  Timer? _sweepTimer;

  @override
  void dispose() {
    _sweepTimer?.cancel();
    super.dispose();
  }

  /// 同一条 URL 重新开始时复用已有条目：既不重复堆积，也顺带清掉上次的错误。
  void start(String url, String postId) {
    final index = state.indexWhere((d) => d.url == url);
    if (index >= 0) {
      final next = [...state];
      next[index] = DownloadProgress(
        url: url,
        postId: postId,
        status: DownloadStatus.downloading,
        progress: 0,
      );
      state = next;
      return;
    }
    state = [...state, DownloadProgress(url: url, postId: postId)];
  }

  void update(String url, double progress) {
    state = state
        .map((d) => d.url == url ? d.copyWith(progress: progress) : d)
        .toList();
  }

  void complete(String url) {
    state = state
        .map((d) => d.url == url
            ? d.copyWith(
                status: DownloadStatus.completed,
                progress: 1.0,
                clearError: true,
              )
            : d)
        .toList();
    _scheduleSweep();
  }

  void fail(String url, String error) {
    state = state
        .map((d) => d.url == url
            ? d.copyWith(status: DownloadStatus.failed, error: error)
            : d)
        .toList();
    _scheduleSweep();
  }

  void remove(String url) {
    state = state.where((d) => d.url != url).toList();
  }

  /// 一次性清理所有终态条目。用单个 Timer 而不是每条一个 delayed：
  /// 此前每完成一次就挂一个 Future.delayed，批量下载时挂出一堆定时器。
  void _scheduleSweep() {
    _sweepTimer?.cancel();
    _sweepTimer = Timer(_terminalTtl, () {
      if (!mounted) return;
      state = state
          .where((d) => d.status == DownloadStatus.downloading)
          .toList();
    });
  }
}
