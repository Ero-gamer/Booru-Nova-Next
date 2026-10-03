import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/media/video_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 视频帖的播放入口：先看帖子自带的 URL，拿不到就**按需向站点解析**。
///
/// 为什么需要这一层：视频站（KVS 家族的 rule34video 等）的列表页只有缩略图，
/// 真正的 mp4/HLS 地址藏在详情页的播放器配置里。若直接在列表条目上用
/// `mediaUrlOf(post)`，拿到的是缩略图 URL——播放器会去「播一张 jpg」。
///
/// 图片站不受影响：它们的 originalUrl 本身就是 mp4/webm，第一层判定即命中，
/// 不会多发任何请求（`resolvePlaybackUrl` 默认返回 null，也不会被调用）。
class ResolvedVideo extends ConsumerStatefulWidget {
  const ResolvedVideo({super.key, required this.post});

  final PostSummary post;

  @override
  ConsumerState<ResolvedVideo> createState() => _ResolvedVideoState();
}

class _ResolvedVideoState extends ConsumerState<ResolvedVideo> {
  String? _resolved;
  bool _loading = false;
  Object? _error;

  /// 播放时附带的请求头（防盗链的站点需要站点的 UA 与 Referer）。
  Map<String, String> _headers = const {};

  @override
  void initState() {
    super.initState();
    final inline = mediaUrlOf(widget.post);
    if (isVideoUrl(inline)) {
      _resolved = inline;
      return;
    }
    _resolve();
  }

  Future<void> _resolve() async {
    final repo = ref.read(booruPageStateProvider.notifier).repository;
    final pageUrl = permalinkOf(widget.post);
    // 必须确认仓库属于这个帖子的站点：切换站点后从历史/下载重开旧帖时，
    // 当前页仓库可能是另一个站点的，拿它去抓详情页只会得到 404 或垃圾。
    final mismatch = repo == null ||
        pageUrl.isEmpty ||
        (widget.post.serverId.isNotEmpty && repo.serverId != widget.post.serverId);
    if (mismatch) {
      setState(() => _error = 'no playback source');
      return;
    }
    // 视频站的媒体地址多数带防盗链：把站点自己的 UA 与「详情页」作为
    // Referer 交给播放器，否则会拿到 403 或 HTML 错误页（表现为播不了）。
    final headers = <String, String>{
      ...repo.mediaHeaders,
      'Referer': pageUrl,
    };
    setState(() {
      _loading = true;
      _error = null;
      _headers = headers;
    });
    try {
      final url = await repo.resolveMediaUrl(pageUrl);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (url == null || url.isEmpty) {
          _error = 'playback url not found';
        } else {
          _resolved = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 44, color: Colors.white54),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _resolve,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(T.retry),
              ),
            ],
          ),
        ),
      );
    }

    final url = _resolved;
    if (_loading || url == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return VideoViewer(
      url: url,
      headers: _headers.isEmpty ? null : _headers,
    );
  }
}
