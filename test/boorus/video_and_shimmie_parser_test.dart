import 'package:boorunova/boorus/kvs/parser/kvs_parser.dart';
import 'package:boorunova/boorus/shimmie2/parser/shimmie2_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// KVS（视频站）与 Shimmie2（paheal 系）的解析测试。
///
/// 固件是按这两个 CMS 家族的真实结构**构造**的：本环境把相关域名污染成了
/// 假 IP，拿不到真实页面。因此这里验证的是「解析逻辑对各种已知形态的处理」，
/// 真机形态确认后应把固件换成抓包结果（与 parser 测试同样的纪律）。
void main() {
  group('KvsParser 列表', () {
    const listHtml = '''
<div class="video-card">
  <a href="https://rule34video.com/videos/1234567/big-breast-blonde-3d/" title="Big Breast Blonde 3D">
    <img class="lazy-load" data-original="https://cdn.example.com/1234567/1.jpg" alt="Big Breast Blonde 3D">
  </a>
  <div class="duration">05:12</div>
</div>
<div class="video-card">
  <a href="/videos/7654321/solo-tease/" title="Solo Tease">
    <img src="/thumbs/7654321.jpg" alt="Solo Tease">
  </a>
  <div class="duration">01:02</div>
</div>
<div class="video-card">
  <a href="/videos/1234567/big-breast-blonde-3d/" title="重复条目">重复</a>
</div>
''';

    test('抽出条目：id / 缩略图绝对化 / 时长 / slug 与标题都进标签', () {
      final posts = KvsParser.parseList(
        'kvs',
        'https://rule34video.com',
        listHtml,
      );

      // 重复 id 只留一条；第三条没有缩略图，跳过
      expect(posts.map((p) => p.id), ['1234567', '7654321']);

      final first = posts.first;
      expect(first.thumbnailUrl, 'https://cdn.example.com/1234567/1.jpg');
      expect(first.postUrl, 'https://rule34video.com/videos/1234567/big-breast-blonde-3d/');
      expect(first.uploader, '05:12');
      expect(first.tags, containsAll(['big', 'breast', 'blonde', '3d']));
      // 相对缩略图要拼成绝对地址
      expect(posts[1].thumbnailUrl, 'https://rule34video.com/thumbs/7654321.jpg');
      // 视频站按限制级记录：安全筛选与侧栏头图应当避开
      expect(first.rating, 'e');
      // 列表页不提供播放地址，留空交给按需解析
      expect(first.originalUrl, isEmpty);
    });
  });

  group('KvsParser 详情页', () {
    test('flashvars 里优先选最高档 mp4（能播也能存）', () {
      const html = '''
<script>var flashvars = {
  video_url: 'https://cdn.example.com/videos/1/video.mp4',
  video_alt_url: 'https://cdn.example.com/videos/1/720p.mp4',
  poster: 'https://cdn.example.com/1/1.jpg'
};</script>
''';
      final video = KvsParser.parseVideoPage(html);
      expect(video, isNotNull);
      expect(video!.url, 'https://cdn.example.com/videos/1/720p.mp4');
      expect(video.poster, 'https://cdn.example.com/1/1.jpg');
    });

    test('只有 HLS 流时也能拿到地址，并反转义 \\/ ', () {
      const html = '''
var flashvars = {"video_url":"https:\\/\\/cdn.example.com\\/hls\\/master.m3u8?token=abc"};
''';
      final video = KvsParser.parseVideoPage(html);
      expect(video?.url,
          'https://cdn.example.com/hls/master.m3u8?token=abc');
    });

    test('没有 flashvars 时退回全局媒体直链（mp4 优先于流清单）', () {
      const html = '''
<video><source src="https://cdn.example.com/v/9/play.m3u8" type="application/x-mpegURL"></video>
<meta property="og:video" content="https://cdn.example.com/v/9/play.mp4">
''';
      expect(KvsParser.parseVideoPage(html)?.url,
          'https://cdn.example.com/v/9/play.mp4');
    });

    test('既没有 flashvars 也没有媒体直链时返回 null（交给 UI 报可重试的错）', () {
      expect(KvsParser.parseVideoPage('<html><body>nothing</body></html>'),
          isNull);
    });
  });

  group('Shimmie2Parser', () {
    test('JSON 接口：字段解析与评级归一', () {
      final posts = Shimmie2Parser.parseJson('shimmie2', {
        'posts': [
          {
            'id': 9001,
            'file': 'https://rule34.paheal.net/_images/abc/9001.png',
            'preview': 'https://rule34.paheal.net/_thumbs/abc/9001.jpg',
            'sample': '',
            'width': 1200,
            'height': 800,
            'tags': ['1girl', 'solo'],
            'rating': 'safe',
          },
          {'id': 9002}, // 缺字段：跳过而不是抛错
        ]
      });

      expect(posts, hasLength(1));
      final post = posts.first;
      expect(post.id, '9001');
      expect(post.thumbnailUrl, contains('_thumbs'));
      expect(post.originalUrl, contains('_images'));
      expect(post.rating, 's');
      expect(post.aspectRatio, closeTo(1.5, 0.001));
      expect(post.tags, ['1girl', 'solo']);
    });

    test('图库 HTML：从 /post/view/<id> 链接反推条目', () {
      const html = '''
<div class="shm-thumb">
  <a href="/post/view/4242" class="thumb">
    <img src="https://rule34.paheal.net/_thumbs/xyz/4242.jpg" alt="1girl solo">
  </a>
</div>
''';
      final posts = Shimmie2Parser.parseList(
        'shimmie2',
        'https://rule34.paheal.net',
        html,
      );

      expect(posts, hasLength(1));
      expect(posts.first.id, '4242');
      expect(posts.first.thumbnailUrl,
          'https://rule34.paheal.net/_thumbs/xyz/4242.jpg');
      expect(posts.first.postUrl, 'https://rule34.paheal.net/post/view/4242');
      expect(posts.first.tags, containsAll(['1girl', 'solo']));
    });

    test('无匹配内容时返回空列表', () {
      expect(
        Shimmie2Parser.parseList('shimmie2', 'https://x', '<html></html>'),
        isEmpty,
      );
      expect(Shimmie2Parser.parseJson('shimmie2', const []), isEmpty);
    });
  });
}
