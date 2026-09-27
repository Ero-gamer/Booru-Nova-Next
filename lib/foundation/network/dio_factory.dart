import 'dart:io';

import 'package:boorunova/foundation/network/hosts_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 统一 Dio 工厂：一处配置超时、UA、hosts 拦截，全项目共用。
class DioFactory {
  DioFactory._();

  /// 全局共享的 hosts 映射，由 registry 初始化时注入。
  /// 下载请求通过此静态持有者默认附加（下载是纯静态工具类，拿不到 Riverpod ref）。
  static HostsInterceptor? sharedHostsInterceptor;

  /// 引擎 API 请求：长接收超时（图站列表可能慢）
  static Dio create({
    String? baseUrl,
    Map<String, dynamic>? headers,
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      headers: headers,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ));
    _installHostsAdapter(dio, hostsInterceptor);
    return dio;
  }

  /// 引擎探测：短超时快速失败
  static Dio createProbe({
    HostsInterceptor? hostsInterceptor,
  }) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (s) => s == 200,
    ));
    _installHostsAdapter(dio, hostsInterceptor);
    return dio;
  }

  /// 文件下载：无接收超时限制，挂 hosts 映射保证自定义 hosts 生效
  static Dio createDownload({HostsInterceptor? hostsInterceptor}) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
    ));
    // 优先用显式传入的映射，否则用全局共享单例（下载请求同样命中 hosts）
    _installHostsAdapter(dio, hostsInterceptor ?? sharedHostsInterceptor);
    return dio;
  }

  static void _installHostsAdapter(Dio dio, HostsInterceptor? hosts) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => createHostsHttpClient(hosts),
    );
  }
}

/// 构造带 hosts 映射的 [HttpClient]。
///
/// 映射只作用在 TCP 连接层：真正建立连接时用映射后的 IP，URL 与 TLS
/// 的 host 始终是原始域名。旧实现靠改写 URL 换 host，会连带丢掉 query
/// 与 Host 头，并让 HTTPS 的 SNI 和证书校验指向 IP 而失败。
///
/// 独立成函数是为了能被直接测试——经过 Dio 的 IOHttpClientAdapter 包装
/// 之后，connectionFactory 的行为无法在测试里单独断言。
///
/// [onBadCertificate] 是证书校验失败时的放行回调。必须显式传入而不是
/// 事后设置 [HttpClient.badCertificateCallback]：接管 connectionFactory
/// 之后 SecureSocket 由我们亲手创建，HttpClient 不会自动接上它自己的
/// 证书回调，只写属性是读不回来的，传不进来。
HttpClient createHostsHttpClient(
  HostsInterceptor? hosts, {
  bool Function(X509Certificate certificate, String host, int port)?
      onBadCertificate,
}) {
  // 保留 HttpClient 默认的 idleTimeout：图站大图下载中间可能长时间没有
  // 数据流，收紧这个值会在服务器正常停顿时直接掐断连接。
  final client = HttpClient();
  if (onBadCertificate != null) {
    client.badCertificateCallback = onBadCertificate;
  }
  client.connectionFactory = (url, proxyHost, proxyPort) {
    // 代理连接必须交给 HttpClient 自己处理 CONNECT 和 TLS 隧道。
    if (proxyHost != null && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }

    final mapped = hosts?.resolve(url.host);
    final target = mapped == null
        ? url.host
        : (InternetAddress.tryParse(mapped) ?? mapped);
    final rawFuture = Socket.startConnect(target, url.port);

    // connectionFactory 接管后，直连 HTTPS 需要显式建立 TLS；host 保持
    // 原始域名以确保 SNI 和证书校验不会因 hosts 映射而改变。
    if (url.scheme != 'https') return rawFuture;
    return rawFuture.then((rawTask) {
      // SecureSocket 的回调只收证书，HttpClient 的收证书+host+port，
      // 这里补上被省略的 host/port，语义与 HttpClient 内部一致。
      final onBad = onBadCertificate == null
          ? null
          : (cert) => onBadCertificate(cert, url.host, url.port);
      final tlsFuture = rawTask.socket.then<Socket>(
        (socket) => SecureSocket.secure(
          socket,
          host: url.host,
          onBadCertificate: onBad,
        ),
      );
      return ConnectionTask.fromSocket<Socket>(tlsFuture, () {
        rawTask.cancel();
        tlsFuture.then((socket) => socket.destroy(), onError: (_) {});
      });
    });
  };
  return client;
}
