import 'dart:async';
import 'dart:ui';

import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/theme/app_dimens.dart';
import 'package:boorunova/presentation/widgets/media/video_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器：直链（mp4/webm）与 HLS（m3u8）都支持——Android 的 ExoPlayer
/// 与 iOS 的 AVPlayer 都原生吃 HLS。
///
/// 控制层是自己实现的（不引依赖）：点击画面显隐、中央播放/暂停、底部
/// 进度条可拖动定位、已播/总时长、倍速、静音、全屏。此前的版本只有一条
/// 极细的进度指示线，实际拖不住，也没有时间显示——用户反馈"没有拖动
/// 进度条等功能"就是它。
class VideoViewer extends StatefulWidget {
  const VideoViewer({
    super.key,
    required this.url,
    this.headers,
    this.autoPlay = true,
  });

  final String url;
  final Map<String, String>? headers;
  final bool autoPlay;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Object? _error;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers ?? const {'User-Agent': 'BooruNova/1.0'},
    );
    _controller = controller;
    controller.addListener(_onControllerChanged);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      if (widget.autoPlay) {
        await controller.play();
      }
      _scheduleHide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// 状态由 controller 持有，这里只重建。
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 只在播放中自动隐藏控制层：暂停时保持可见，否则用户找不到按钮。
  void _scheduleHide() {
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      // 播完后按播放键 = 从头重播
      if (controller.value.isCompleted) {
        controller.seekTo(Duration.zero);
      }
      controller.play();
      _scheduleHide();
    }
  }

  /// 全屏：不新建控制器（避免重新缓冲与跳回 0 秒），把同一个控制器交给
  /// 全屏页显示，退出时再交回来。
  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullscreenVideoPage(
          controller: controller,
          onClose: () => Navigator.of(context).maybePop(),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final old = _controller;
    old?.removeListener(_onControllerChanged);
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _controller = null;
      _initialized = false;
      _error = null;
    });
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return _VideoError(error: error, onRetry: _retry);

    final controller = _controller;
    if (!_initialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final aspect = controller.value.aspectRatio;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect > 0 ? aspect : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (controller.value.isBuffering)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ),
        AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: _ControlsLayer(
              controller: controller,
              isFullscreen: false,
              onTogglePlay: _togglePlay,
              onToggleFullscreen: _openFullscreen,
            ),
          ),
        ),
        if (controller.value.isCompleted)
          Center(
            child: _RoundIconButton(
              icon: Icons.replay,
              tooltip: T.replay,
              size: 60,
              onTap: _togglePlay,
            ),
          ),
      ],
    );
  }
}

/// 控制层：上下渐变 + 中央播放键 + 底部控制条。
class _ControlsLayer extends StatelessWidget {
  const _ControlsLayer({
    required this.controller,
    required this.isFullscreen,
    required this.onTogglePlay,
    this.onToggleFullscreen,
    this.onClose,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onTogglePlay;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 渐变只为提升图标可读性，不挡视频
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.transparent,
                Colors.black87,
              ],
              stops: [0, 0.22, 0.55, 1],
            ),
          ),
        ),
        Center(
          child: _RoundIconButton(
            icon: controller.value.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            tooltip: controller.value.isPlaying ? T.pause : T.play,
            size: 68,
            onTap: onTogglePlay,
          ),
        ),
        if (onClose != null)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: _RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: T.exitFullscreen,
                size: 40,
                onTap: onClose!,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: _ControlBar(
              controller: controller,
              isFullscreen: isFullscreen,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部控制条：进度拖动 + 时间 + 倍速 + 静音 + 全屏。
///
/// 拖动状态（`_dragMs`）放在这里：拖动期间以手指位置为准，不被播放进度
/// 拉回去；松手才真正 seek。此前直接绑控制器进度，滑块一碰就弹回原处。
class _ControlBar extends StatefulWidget {
  const _ControlBar({
    required this.controller,
    required this.isFullscreen,
    this.onToggleFullscreen,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  /// 拖动中的目标毫秒；非空表示正在拖。
  double? _dragMs;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  void _seekTo(double ms) {
    widget.controller.seekTo(Duration(milliseconds: ms.round()));
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final totalMs = value.duration.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final shownMs = (_dragMs ?? value.position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);
    final muted = value.volume == 0;
    final speed = value.playbackSpeed;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusM),
      ),
      child: BackdropFilter(
        // 给控制条一点液态玻璃的底子，与全局观感统一
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          // Flutter 3.24 上还没有 Color.withValues（3.27+ 才引入），
          // 与项目其余 40 处保持一致用 withOpacity。
          // ignore: deprecated_member_use
          color: Colors.black.withOpacity(0.42),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: shownMs,
                  max: maxMs,
                  // 拖动中即时跟手；松手才 seek
                  onChanged: (v) => setState(() => _dragMs = v),
                  onChangeEnd: (v) {
                    _seekTo(v);
                    setState(() => _dragMs = null);
                  },
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 6),
                  Text(
                    '${_fmt(Duration(milliseconds: shownMs.round()))}'
                    ' / ${_fmt(value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  // 倍速
                  PopupMenuButton<double>(
                    tooltip: T.playbackSpeed,
                    initialValue: speed,
                    onSelected: (v) => widget.controller.setPlaybackSpeed(v),
                    itemBuilder: (_) => [
                      for (final s in _speeds)
                        PopupMenuItem(
                          value: s,
                          child: Text('${s == s.roundToDouble() ? s.toInt() : s}x'),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(
                        '${speed == speed.roundToDouble() ? speed.toInt() : speed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: muted ? T.unmute : T.mute,
                    icon: Icon(
                      muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        widget.controller.setVolume(muted ? 1 : 0),
                  ),
                  if (widget.onToggleFullscreen != null)
                    IconButton(
                      tooltip: widget.isFullscreen
                          ? T.exitFullscreen
                          : T.fullscreen,
                      icon: Icon(
                        widget.isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                      ),
                      onPressed: widget.onToggleFullscreen,
                    ),
                  const SizedBox(width: 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `mm:ss`，超过一小时给 `h:mm:ss`。
  static String _fmt(Duration d) => formatVideoDuration(d);
}

/// 全屏播放页：同一个控制器换个容器显示，并临时锁定横屏 + 沉浸式。
class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({required this.controller, required this.onClose});

  final VideoPlayerController controller;
  final VoidCallback onClose;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // 与 main.dart 允许的方向保持一致，退出时原样恢复
    unawaited(SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final aspect = controller.value.aspectRatio;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _visible = !_visible),
            child: Center(
              child: AspectRatio(
                aspectRatio: aspect > 0 ? aspect : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (controller.value.isBuffering)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_visible,
              child: _ControlsLayer(
                controller: controller,
                isFullscreen: true,
                onTogglePlay: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    if (controller.value.isCompleted) {
                      controller.seekTo(Duration.zero);
                    }
                    controller.play();
                  }
                },
                onToggleFullscreen: widget.onClose,
                onClose: widget.onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 圆形半透明按钮：控制层里统一的手感与命中区。
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.6),
          ),
        ),
      ),
    );
  }
}

/// 播放失败时的可恢复界面：坏链、编码不支持、防盗链都落在这里。
///
/// 关键是把「转圈到底」换成「告诉你失败 + 给一次重试」——视频站的外链
/// 常常需要 token，失败是常态而不是异常。
class _VideoError extends StatelessWidget {
  const _VideoError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                size: 48, color: Colors.white54),
            const SizedBox(height: AppDimens.spaceM),
            Text(
              T.videoPlayFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: AppDimens.spaceXS),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: AppDimens.spaceM),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(T.retry),
            ),
          ],
        ),
      ),
    );
  }
}
