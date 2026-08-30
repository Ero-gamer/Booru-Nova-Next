import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:dio/dio.dart';

class HostsInterceptor extends Interceptor {
  HostsInterceptor({required this.enabled, required UserHostsRepo repo})
      : _repo = repo;

  final UserHostsRepo _repo;
  bool enabled;

  bool get _isActive {
    if (enabled) return true;
    try {
      final raw = HiveSetup.settingsBox.get('app_settings');
      if (raw is Map) {
        return raw['hostsEnabled'] == true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isActive) return handler.next(options);

    // 优先从 baseUrl 取 host；下载/探测等空 baseUrl + 绝对 URL path 的请求，
    // 尝试从 path 解析出 host，让它们同样命中自定义 hosts 映射。
    var uri = options.baseUrl.isNotEmpty
        ? Uri.tryParse(options.baseUrl)
        : null;
    var requestPath = options.path;
    if (uri == null || uri.host.isEmpty) {
      final asAbsolute = Uri.tryParse(requestPath);
      if (asAbsolute != null && asAbsolute.host.isNotEmpty) {
        uri = asAbsolute;
        requestPath = asAbsolute.hasQuery
            ? asAbsolute.path
            : asAbsolute.path;
      }
    }
    if (uri == null || uri.host.isEmpty) return handler.next(options);

    final mapping = _repo.match(uri.host);
    if (mapping == null) return handler.next(options);

    // 保留原 scheme：绝不把 https 降级为明文 http，避免携带认证头时明文传输。
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
    final path = requestPath.startsWith('/')
        ? requestPath
        : '/$requestPath';
    final newUrl = Uri(
      scheme: scheme,
      host: mapping.ip,
      path: path,
      queryParameters: options.queryParameters.isNotEmpty
          ? options.queryParameters.map((k, v) => MapEntry(k, v.toString()))
          : null,
    );

    options.baseUrl = '$scheme://${mapping.ip}';
    options.path = newUrl.path;
    // 注意：不能清空 queryParameters —— Dio 拼接 URL 时会把 options.path 与
    // options.queryParameters 合并。若 clear()，则命中 hosts 的请求会丢失
    // 全部搜索/过滤参数（tags、limit 等）。保留原参数即可让它们跟上新 host。
    options.headers['Host'] = uri.host;

    handler.next(options);
  }
}
