import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/presentation/screens/server/booru_site_template.dart';
import 'package:flutter/material.dart';

/// 站点图标：优先拉站点自己的 favicon，失败则回落到引擎品牌图标。
///
/// 抽成共享组件的原因：此前首页与服务器页各写一份。首页那版有失败缓存
/// 和品牌图标兜底，服务器页只有一个 `Icons.public` —— 同一个站点在两个
/// 页面显示不同的占位图标，看起来像加载失败。
///
/// 失败集合是进程级静态：某个站点 favicon 404 之后本次运行不再重试，
/// 避免每次 rebuild 都发一次注定失败的请求。
class ServerFavicon extends StatelessWidget {
  const ServerFavicon({
    super.key,
    required this.baseUrl,
    required this.type,
    this.size = 24,
  });

  final String baseUrl;
  final BooruType type;
  final double size;

  static final Set<String> _failed = <String>{};

  static String faviconUrlOf(String baseUrl) {
    final clean =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$clean/favicon.ico';
  }

  @override
  Widget build(BuildContext context) {
    final url = faviconUrlOf(baseUrl);
    if (url.isEmpty || _failed.contains(url)) {
      return EngineIcon(type: type, size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          // 记入失败集合，后续渲染直接走兜底，不再重复请求
          _failed.add(url);
          return EngineIcon(type: type, size: size);
        },
      ),
    );
  }
}

/// 引擎品牌图标：模板色底 + 模板图标。站点 favicon 不可用时的统一兜底。
class EngineIcon extends StatelessWidget {
  const EngineIcon({super.key, required this.type, this.size = 24});

  final BooruType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final template = BooruSiteTemplate.findByType(type);
    final fallback = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = template?.color ?? fallback;
    return CircleAvatar(
      radius: size / 2 + 2,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(template?.icon ?? Icons.dns_outlined,
          color: color, size: size),
    );
  }
}
