import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器：支持直链（mp4/webm）与 HLS（m3u8）——Android 的 ExoPlayer
/// 与 iOS 的 AVPlayer 都原生吃 HLS，所以视频站只给流清单也能播。
///
/// 纠了三处此前的问题：
/// 1. 没有 `addListener`：播放/暂停图标读的是 `_controller.value.isPlaying`，
///    而它只在点击回调里被 setState 刷新过一次——播放自然结束或缓冲状态变化
///    都不会重建，图标与真实状态长期不一致。
/// 2. `initialize()` 没有错误处理：坏链或编码不支持时 `_initialized` 永远
///    false，用户看到的是一个永不结束的转圈。
/// 3. `setState` 包的是 `play()` 这个副作用而不是状态变化。
class VideoViewer extends StatefulWidget {
  const VideoViewer({super.key, required this.url, this.headers});

  final String url;
  final Map<String, String>? headers;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers ??
          const {'User-Agent': 'BooruNova/1.0'},
    );
    _controller = controller;
    controller.addListener(_onControllerChanged);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// 只做重建：状态由 controller 持有，这里不复制一份。
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspect > 0 ? aspect : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            const Center(
              child: Icon(Icons.play_circle, color: Colors.white70, size: 64),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              T.videoPlayFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
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
