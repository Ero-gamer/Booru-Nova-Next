import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// 侧栏左上角的随机装饰图：从公开图片网址随机取一张「正常」图片垫底，
/// 让抽屉顶部不至于是一片空白玻璃。
///
/// 为什么不用图站内容：图站图片可能是限制级，出现在导航侧栏这种应用
/// 外壳位置并不合适；而且侧栏是随时可用的导航，不该依赖用户当前站点
/// 是否可用、是否配好了 API Key。所以这里用公开图片源。
///
/// 工程约束（与 glass.dart 的性能约束同一套取舍）：
/// - 每次创建（= 每次滑出侧栏）随机挑一个源，并尽量避开上一次那个，
///   否则「随机」在视觉上等于没换；
/// - 候选源顺序回退：当前源失败就换下一个；全部失败只剩主题渐变兜底，
///   离线时侧栏依然完整可用，只是没有照片；
/// - 失败源只封禁 [_banDuration] 而不是永久拉黑：断网期间所有源都会失败，
///   永久拉黑会让用户在恢复网络后再也看不到图；
/// - [_timeLimit] + [retries]：装饰图不值得让用户盯着占位等半分钟，
///   宁可快速失败换源；
/// - 交给 extended_image 做内存 + 磁盘缓存，重复打开不再重复下载。
class RandomCoverArt extends StatefulWidget {
  const RandomCoverArt({super.key});

  /// 单个源的最长等待时间。
  static const Duration _timeLimit = Duration(seconds: 8);

  /// 失败源的封禁时长。
  static const Duration _banDuration = Duration(minutes: 10);

  @override
  State<RandomCoverArt> createState() => _RandomCoverArtState();
}

class _RandomCoverArtState extends State<RandomCoverArt> {
  /// 候选源：全部是「直接返回图片字节」的网址（不是返回 JSON 的接口），
  /// 因此可以整体交给图片组件。`{seed}` 每次替换成随机串，这一类源
  /// 每次打开都是新图片；其余的会被磁盘缓存命中，重复打开不再下载。
  ///
  /// 写死而不是做成配置：这几个地址是实测能直出图片的，换一个源就是
  /// 一次线上事故（返回 HTML、需要 referer、超时），没有让用户在设置里
  /// 自担风险的道理。要加源在这里加即可。
  static const List<String> _sources = <String>[
    'https://picsum.photos/seed/{seed}/900/560',
    'https://picsum.photos/seed/boorunova/900/560',
    'https://img.xjh.me/random_img.php?type=bg&ctype=nature&return=302',
    'https://t.alcy.cc/pc',
    'https://t.alcy.cc/mp',
  ];

  static final Random _random = Random();

  /// 失败源 → 失败时间。键是源模板本身，`{seed}` 类源共用一条记录。
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};

  /// 上一次成功用过的源，用于避免连续两次同一张图。
  static String? _lastSource;

  /// 本次可用的源（已打乱）。空表示所有源都在封禁期，直接走兜底。
  late final List<String> _candidates;

  /// 当前正在加载的地址。在这里存住而不是每次 build 现算：
  /// `{seed}` 每次替换结果不同，重建（换主题、旋转屏幕）会变成新地址，
  /// 等于把已经下好的图再下一次。
  String _url = '';

  int _index = 0;

  /// 防止同一帧里失败回调重入时连续跳好几个源。
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final alive = _sources.where((s) => !_isBanned(s, now)).toList()
      ..shuffle(_random);
    // 尽量不和上一次撞车：随机挑一个别的源放到队首。
    if (alive.length > 1 && alive.first == _lastSource) {
      final swapWith = 1 + _random.nextInt(alive.length - 1);
      final head = alive.first;
      alive[0] = alive[swapWith];
      alive[swapWith] = head;
    }
    _candidates = alive;
    if (alive.isNotEmpty) _url = _materialize(alive.first);
  }

  static bool _isBanned(String source, DateTime now) {
    final at = _failedAt[source];
    return at != null && now.difference(at) < RandomCoverArt._banDuration;
  }

  static String _materialize(String source) => source.contains('{seed}')
      ? source.replaceFirst(
          '{seed}', _random.nextInt(1 << 30).toRadixString(36))
      : source;

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) return const _CoverFallback();
    return ExtendedImage.network(
      _url,
      fit: BoxFit.cover,
      cache: true,
      // 装饰图是固定的几个地址，缓存久一点，重复打开不再回源。
      cacheMaxAge: const Duration(days: 7),
      // 头图最宽也就几百逻辑像素，没必要按 4K 原图解码。
      cacheWidth: 900,
      timeLimit: RandomCoverArt._timeLimit,
      retries: 1,
      gaplessPlayback: true,
      loadStateChanged: _onLoadState,
    );
  }

  /// 加载状态回调。注意这里会被 `build` 调用，所以只做「记账」，
  /// 需要重建时用 post-frame 回调，避免 setState during build。
  Widget _onLoadState(ExtendedImageState state) {
    switch (state.extendedImageLoadState) {
      case LoadState.completed:
        _lastSource = _candidates[_index];
        return state.completedWidget;
      case LoadState.loading:
        return const _CoverFallback();
      case LoadState.failed:
        _failedAt[_candidates[_index]] = DateTime.now();
        _advance();
        return const _CoverFallback();
    }
  }

  void _advance() {
    if (_advancing) return;
    final next = _index + 1;
    // 没有后备源了：保持兜底渐变，不再继续试。
    if (next >= _candidates.length) return;
    _advancing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _index = next;
        _url = _materialize(_candidates[next]);
        _advancing = false;
      });
    });
  }
}

/// 没有可用图片时的兜底：主题渐变。
///
/// 不能留白：头图区域纯装饰，空白会让滑出的抽屉看起来像没加载完。
/// 渐变最终会被头部的压暗层盖住，所以只用亮色即可，不需要做对比度。
class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.85),
              colorScheme.primaryContainer,
              colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
      ),
    );
  }
}
