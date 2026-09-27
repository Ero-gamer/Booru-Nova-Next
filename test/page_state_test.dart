import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假引擎：按脚本返回结果或抛错，用于验证状态机的时序分支。
class _FakeRepo implements BooruRepository {
  _FakeRepo({this.onSearch});

  final Future<BooruPageResult> Function(BooruQuery query)? onSearch;

  @override
  String get serverId => 'fake';

  @override
  Future<BooruPageResult> searchPosts(BooruQuery query) async {
    final handler = onSearch;
    if (handler == null) {
      return const BooruPageResult(posts: [], hasMore: false);
    }
    return handler(query);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostSummary _post(String id) => PostSummary(
      id: id,
      thumbnailUrl: 'https://example.test/$id-thumb.jpg',
      sampleUrl: 'https://example.test/$id.jpg',
      originalUrl: 'https://example.test/$id-orig.jpg',
      tags: const ['tag'],
      aspectRatio: 1,
      width: 100,
      height: 100,
      rating: 's',
      score: 0,
      serverId: 'fake',
    );

void main() {
  group('BooruPageState.copyWith', () {
    test('不传 error 时保留原值', () {
      const state = BooruPageState(error: 'boom');
      expect(state.copyWith(isLoading: true).error, 'boom');
    });

    test('显式传 null 时清空 error', () {
      // 回归点：旧实现是 `error ?? this.error`，error: null 静默失效，
      // 一次失败后过期错误文案会永久残留。
      const state = BooruPageState(error: 'boom');
      expect(state.copyWith(error: null).error, isNull);
    });

    test('serverId 同样支持显式置空', () {
      const state = BooruPageState(serverId: 'a');
      expect(state.copyWith(serverId: null).serverId, isNull);
      expect(state.copyWith(isLoading: true).serverId, 'a');
    });
  });

  group('BooruPageNotifier', () {
    test('搜索成功后清掉上一次的错误', () async {
      var failNext = true;
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final repo = _FakeRepo(onSearch: (_) async {
        if (failNext) throw StateError('network down');
        return const BooruPageResult(posts: [], hasMore: false);
      });
      await notifier.switchServer(repo);

      await notifier.search('hatsune');
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);

      // 第二次搜索成功但返回 0 条：必须是「无结果」而不是残留的旧错误
      failNext = false;
      await notifier.search('nekosune');
      expect(notifier.state.error, isNull);
      expect(notifier.state.posts, isEmpty);
    });

    test('翻页失败保留已有内容并置 pagingFailed', () async {
      var page = 1;
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final repo = _FakeRepo(onSearch: (q) async {
        if (q.page > 1) throw StateError('paging failed');
        page = q.page;
        return BooruPageResult(posts: [_post('a')], hasMore: true);
      });
      await notifier.switchServer(repo);
      expect(notifier.state.posts, hasLength(1));
      expect(page, 1);

      await notifier.loadMore();
      expect(notifier.state.pagingFailed, isTrue);
      // 已有内容不能被翻页错误清空
      expect(notifier.state.posts, hasLength(1));
      // 首屏 error 不应被翻页失败污染
      expect(notifier.state.error, isNull);
      // 页码不前进，重试时仍拉同一页
      expect(notifier.state.currentPage, 1);
    });

    test('pagingFailed 后 loadMore 不再自动重试', () async {
      var attempts = 0;
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final repo = _FakeRepo(onSearch: (q) async {
        attempts++;
        if (q.page > 1) throw StateError('paging failed');
        return BooruPageResult(posts: [_post('a')], hasMore: true);
      });
      await notifier.switchServer(repo);
      final baseline = attempts;

      await notifier.loadMore();
      final afterFailure = attempts;

      // 连续滚动不应继续打请求
      await notifier.loadMore();
      await notifier.loadMore();
      expect(attempts, afterFailure);
      expect(attempts, baseline + 1);
    });

    test('retryLoadMore 清标记后重试同一页', () async {
      var failPaging = true;
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      final repo = _FakeRepo(onSearch: (q) async {
        if (q.page > 1 && failPaging) throw StateError('paging failed');
        return BooruPageResult(
          posts: [_post('p${q.page}')],
          hasMore: true,
        );
      });
      await notifier.switchServer(repo);
      await notifier.loadMore();
      expect(notifier.state.pagingFailed, isTrue);
      expect(notifier.state.posts, hasLength(1));

      failPaging = false;
      await notifier.retryLoadMore();
      expect(notifier.state.pagingFailed, isFalse);
      expect(notifier.state.currentPage, 2);
      expect(notifier.state.posts, hasLength(2));
    });

    test('未选站点时写入可本地化的哨兵错误', () async {
      final notifier = BooruPageNotifier();
      addTearDown(notifier.dispose);

      await notifier.search('anything');
      expect(notifier.state.error, kNoServerSelected);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
