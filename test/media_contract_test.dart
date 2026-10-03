import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/foundation/util/download_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// 媒体 URL 判定与评级归一的契约测试。
///
/// 这两件事是「视频站能进软件」的地基：HLS 地址不被当成视频，视频帖就会被
/// 丢给图片组件渲染（永远加载中的破图）；评级不归一，详情页会显示
/// "SENSITIVE"、徽章变灰。
void main() {
  group('视频判定 (isVideoUrl)', () {
    test('直链与流清单都算视频', () {
      expect(isVideoUrl('https://x/v/a.mp4'), isTrue);
      expect(isVideoUrl('https://x/v/a.webm'), isTrue);
      // HLS / DASH：视频站常只给这种地址（此前不认，会当图片渲染）
      expect(isVideoUrl('https://x/hls/master.m3u8'), isTrue);
      expect(isVideoUrl('https://x/dash/manifest.mpd'), isTrue);
      // 带防盗链参数
      expect(isVideoUrl('https://x/hls/master.m3u8?token=abc&e=1'), isTrue);
      expect(isVideoUrl('https://x/v/a.mp4?t=1'), isTrue);
      // 路径含 /video/ 的站点惯例
      expect(isVideoUrl('https://x/video/1234'), isTrue);
    });

    test('图片不算视频', () {
      expect(isVideoUrl('https://x/1.jpg'), isFalse);
      expect(isVideoUrl('https://x/sample/1.png'), isFalse);
      expect(isVideoUrl(''), isFalse);
    });

    test('isVideoPost 认 sample 或 original 任一命中', () {
      PostSummary post({String sample = '', String original = ''}) =>
          PostSummary(
            id: '1',
            serverId: 's',
            thumbnailUrl: 'https://x/t.jpg',
            sampleUrl: sample,
            originalUrl: original,
            tags: const [],
            aspectRatio: 1,
            width: 1,
            height: 1,
            rating: 'e',
            score: 0,
          );

      expect(isVideoPost(post(original: 'https://x/v.mp4')), isTrue);
      expect(isVideoPost(post(sample: 'https://x/hls/a.m3u8')), isTrue);
      expect(isVideoPost(post(original: 'https://x/a.jpg')), isFalse);
    });
  });

  group('下载路径与扩展名', () {
    test('扩展名口径唯一：剥 query/fragment', () {
      expect(extensionOf('https://x/a/b.jpg?v=1'), '.jpg');
      expect(extensionOf('https://x/a/b.jpg#frag'), '.jpg');
      expect(extensionOf('https://x/a/b'), '');
      expect(isVideoFile('https://x/a/b.mp4'), isTrue);
      expect(isVideoFile('https://x/a/b.m3u8'), isFalse,
          reason: '流清单不是可下载的视频文件');
    });

    test('流清单被识别出来（下载层据此拒绝，播放不受影响）', () {
      expect(isStreamManifest('https://x/hls/a.m3u8?t=1'), isTrue);
      expect(isStreamManifest('https://x/d/a.mpd'), isTrue);
      expect(isStreamManifest('https://x/a/a.mp4'), isFalse);
    });

    test('文件名：无扩展名时不再产出无后缀文件（Gal 会因此抛异常）', () {
      // 此前守卫与文件名是两套口径：`.../1234?tag=a.b` 能过守卫，
      // 生成的名字却没有扩展名，落盘后 Gal 抛 FileNotFoundException。
      expect(extensionOf('https://x/i/1234?tag=a.b'), '');
      expect(uniqueFileName('https://x/i/1234?tag=a.b'), '1234');
      // 正常 URL 仍保留扩展名与 postId 前缀
      expect(uniqueFileName('https://x/i/a.jpg?v=1', postId: '42'),
          '42_a.jpg');
    });
  });

  group('评级归一 (normalizeRating)', () {
    test('长名与短码都收敛到 s/q/e，未知落 q', () {
      for (final safe in ['s', 'S', 'safe', 'general', 'g', ' general ']) {
        expect(normalizeRating(safe), 's', reason: safe);
      }
      expect(normalizeRating('questionable'), 'q');
      expect(normalizeRating('q'), 'q');
      expect(normalizeRating('explicit'), 'e');
      expect(normalizeRating('e'), 'e');
      // 未知值落 q 而不是 e：把不确定当限制级会误伤安全筛选
      expect(normalizeRating('whatever'), 'q');
      expect(normalizeRating(null), 'q');
      expect(normalizeRating(''), 'q');
    });
  });
}
