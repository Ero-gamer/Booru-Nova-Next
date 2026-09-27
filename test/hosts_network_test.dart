import 'dart:io';

import 'package:boorunova/data/repository/hosts/entity/host_entry.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/network/hosts_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('boorunova_hosts_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveSetup.settingsBoxName);
    await Hive.openBox(HiveSetup.serversBoxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  test('hosts matching respects domain boundaries and case', () async {
    final repo = UserHostsRepo();
    await repo.add(const HostEntry(domain: 'Example.COM', ip: '127.0.0.1'));

    expect(repo.match('example.com')?.ip, '127.0.0.1');
    expect(repo.match('IMG.Example.Com')?.ip, '127.0.0.1');
    expect(repo.match('example.com.')?.ip, '127.0.0.1');
    expect(repo.match('notexample.com'), isNull);
    expect(repo.match('example.com.evil.test'), isNull);
  });

  test('mapped HTTP request keeps original query and reaches mapped IP',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requestFuture = server.first;

    final hosts = UserHostsRepo();
    await hosts.add(const HostEntry(domain: 'mapped.test', ip: '127.0.0.1'));
    await HiveSetup.settingsBox
        .put('app_settings', const {'hostsEnabled': true});
    final interceptor = HostsInterceptor(enabled: false, repo: hosts);
    final dio = DioFactory.create(
      hostsInterceptor: interceptor,
      baseUrl: 'http://mapped.test:${server.port}',
    );

    final responseFuture = dio.get('/probe?json=1&signature=a%2Bb');
    final request = await requestFuture;
    expect(request.uri.path, '/probe');
    expect(request.uri.queryParameters, {
      'json': '1',
      'signature': 'a+b',
    });
    request.response
      ..statusCode = HttpStatus.ok
      ..write('ok');
    await request.response.close();

    final response = await responseFuture;
    expect(response.data, 'ok');
  });

  group('HTTPS 映射', () {
    /// 起一个自签 TLS 服务器，证书签给 mapped.test。
    ///
    /// 直接用 [createHostsHttpClient] 而非经由 Dio：Dio 的
    /// IOHttpClientAdapter 包装下，测试无法给内部 HttpClient 注入证书
    /// 信任（HttpOverrides 会与 adapter 互相递归到栈溢出），connectionFactory
    /// 的行为也就无从断言。
    Future<HttpServer> serveTls() async {
      final context = SecurityContext()
        ..useCertificateChain(_fixture('mapped_test.crt'))
        ..usePrivateKey(_fixture('mapped_test.key'));
      final server =
          await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
      addTearDown(() => server.close(force: true));
      return server;
    }

    test('映射后的 HTTPS 请求到达映射 IP 并完成 TLS 握手', () async {
      final server = await serveTls();
      final requestFuture = server.first;

      final hosts = UserHostsRepo();
      await hosts.add(const HostEntry(domain: 'mapped.test', ip: '127.0.0.1'));
      await HiveSetup.settingsBox
          .put('app_settings', const {'hostsEnabled': true});

      final client = createHostsHttpClient(
        HostsInterceptor(enabled: true, repo: hosts),
        // 自签证书不在系统信任库里，放行证书来源；证书校验本身仍由
        // SecureSocket.secure 的主机名匹配把关。
        onBadCertificate: (_, __, ___) => true,
      );
      addTearDown(() => client.close(force: true));

      final uri =
          Uri.parse('https://mapped.test:${server.port}/posts/1?tags=hatsune');
      // 先把请求发出去，再等服务端应答——Stream.first 拿到请求后
      // stream 即被取消，不会有人替它写响应。
      final responseFuture = (await client.getUrl(uri)).close();

      final served = await requestFuture;
      expect(served.uri.path, '/posts/1');
      expect(served.uri.queryParameters['tags'], 'hatsune');
      served.response.statusCode = HttpStatus.ok;
      await served.response.close();

      // 请求打到了本机（映射生效），而 path 与 query 保持原样——
      // 靠改写 URL 换 host 的旧实现会在这里丢掉 query。
      expect((await responseFuture).statusCode, HttpStatus.ok);
    });

    test('未启用 hosts 时不套用映射，请求打不到本机服务器', () async {
      // unmapped.invalid 是 RFC 2606 保留 TLD，必然解析失败。
      // 若映射被错误套用，连接会命中本机并成功——那正是回归。
      final server = await serveTls();
      var servedRequests = 0;
      server.listen((request) {
        servedRequests++;
        request.response.statusCode = HttpStatus.ok;
        request.response.close();
      });

      final hosts = UserHostsRepo();
      await hosts
          .add(const HostEntry(domain: 'unmapped.invalid', ip: '127.0.0.1'));

      final client = createHostsHttpClient(
        HostsInterceptor(enabled: false, repo: hosts),
        onBadCertificate: (_, __, ___) => true,
      );
      addTearDown(() => client.close(force: true));

      await expectLater(
        client
            .getUrl(Uri.parse('https://unmapped.invalid:${server.port}/probe'))
            .then((req) => req.close()),
        throwsA(isA<SocketException>()),
      );

      // 留一拍让潜在的迟到连接落地，再断言服务器没被命中。
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(servedRequests, 0);
    });
  });
}

String _fixture(String name) =>
    '${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}fixtures${Platform.pathSeparator}$name';
