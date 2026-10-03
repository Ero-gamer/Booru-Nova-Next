import 'dart:convert';

import 'package:boorunova/boorus/danbooru/danbooru.dart';
import 'package:boorunova/boorus/danbooru/danbooru_repository.dart';
import 'package:boorunova/boorus/e621/e621.dart';
import 'package:boorunova/boorus/e621/e621_repository.dart';
import 'package:boorunova/boorus/engine/booru_engine.dart';
import 'package:boorunova/boorus/engine/booru_repository.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorunova/boorus/gelbooru_v2/gelbooru_v2_repository.dart';
import 'package:boorunova/boorus/kvs/kvs.dart';
import 'package:boorunova/boorus/kvs/kvs_repository.dart';
import 'package:boorunova/boorus/moebooru/moebooru.dart';
import 'package:boorunova/boorus/moebooru/moebooru_repository.dart';
import 'package:boorunova/boorus/rule34/rule34.dart';
import 'package:boorunova/boorus/rule34/rule34_repository.dart';
import 'package:boorunova/boorus/safebooru/safebooru.dart';
import 'package:boorunova/boorus/safebooru/safebooru_repository.dart';
import 'package:boorunova/boorus/sankaku/sankaku.dart';
import 'package:boorunova/boorus/sankaku/sankaku_repository.dart';
import 'package:boorunova/boorus/shimmie2/shimmie2.dart';
import 'package:boorunova/boorus/shimmie2/shimmie2_repository.dart';
import 'package:boorunova/boorus/zerochan/zerochan.dart';
import 'package:boorunova/boorus/zerochan/zerochan_repository.dart';
import 'package:boorunova/data/repository/hosts/user_hosts_repo.dart';
import 'package:boorunova/foundation/network/dio_factory.dart';
import 'package:boorunova/foundation/network/hosts_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final booruRegistryProvider = Provider<BooruRegistry>((ref) {
  final registry = BooruRegistry();
  _registerDefaults(registry);
  final interceptor = ref.read(hostsInterceptorProvider);
  registry.hostsInterceptor = interceptor;
  // 共享给下载等静态工具类：让下载请求同样命中自定义 hosts 映射
  DioFactory.sharedHostsInterceptor = interceptor;
  return registry;
});

final hostsInterceptorProvider = Provider<HostsInterceptor>((ref) {
  final repo = ref.read(userHostsRepoProvider);
  return HostsInterceptor(enabled: false, repo: repo);
});

void _registerDefaults(BooruRegistry registry) {
  registry.register(BooruType.danbooru, () => BooruEngine(
        booru: const Danbooru(),
        repositoryFactory: (dio, {serverId}) =>
            DanbooruRepository(dio: dio, serverId: serverId ?? 'danbooru'),
      ));

  registry.register(BooruType.gelbooruV2, () => BooruEngine(
        booru: const GelbooruV2(),
        repositoryFactory: (dio, {serverId}) => GelbooruV2Repository(
            dio: dio, serverId: serverId ?? 'gelbooru_v2'),
      ));

  registry.register(BooruType.moebooru, () => BooruEngine(
        booru: const Moebooru(),
        repositoryFactory: (dio, {serverId}) =>
            MoebooruRepository(dio: dio, serverId: serverId ?? 'moebooru'),
      ));

  registry.register(BooruType.e621, () => BooruEngine(
        booru: const E621(),
        repositoryFactory: (dio, {serverId}) =>
            E621Repository(dio: dio, serverId: serverId ?? 'e621'),
      ));

  registry.register(BooruType.sankaku, () => BooruEngine(
        booru: const Sankaku(),
        repositoryFactory: (dio, {serverId}) =>
            SankakuRepository(dio: dio, serverId: serverId ?? 'sankaku'),
      ));

  registry.register(BooruType.zerochan, () => BooruEngine(
        booru: const Zerochan(),
        repositoryFactory: (dio, {serverId}) =>
            ZerochanRepository(dio: dio, serverId: serverId ?? 'zerochan'),
      ));

  registry.register(BooruType.rule34, () => BooruEngine(
        booru: const Rule34(),
        repositoryFactory: (dio, {serverId}) =>
            Rule34Repository(dio: dio, serverId: serverId ?? 'rule34'),
      ));

  registry.register(BooruType.safebooru, () => BooruEngine(
        booru: const Safebooru(),
        repositoryFactory: (dio, {serverId}) =>
            SafebooruRepository(dio: dio, serverId: serverId ?? 'safebooru'),
      ));

  // rule34 家族：paheal 系（Shimmie2）与视频站（KVS）
  registry.register(BooruType.shimmie2, () => BooruEngine(
        booru: const Shimmie2(),
        repositoryFactory: (dio, {serverId}) =>
            Shimmie2Repository(dio: dio, serverId: serverId ?? 'shimmie2'),
      ));

  registry.register(BooruType.kvs, () => BooruEngine(
        booru: const KvsTube(),
        repositoryFactory: (dio, {serverId}) =>
            KvsRepository(dio: dio, serverId: serverId ?? 'kvs'),
      ));
}

class BooruRegistry {
  final Map<BooruType, BooruEngine Function()> _factories = {};
  final Map<BooruType, BooruEngine> _singletons = {};

  HostsInterceptor? hostsInterceptor;

  void register(BooruType type, BooruEngine Function() factory) {
    _factories[type] = factory;
  }

  BooruEngine? get(BooruType type) {
    if (!_factories.containsKey(type)) return null;
    if (!_singletons.containsKey(type)) {
      _singletons[type] = _factories[type]!();
    }
    return _singletons[type];
  }

  static const _probePaths = <BooruType, String>{
    BooruType.danbooru: '/posts.json?limit=1',
    BooruType.moebooru: '/post.json?limit=1',
    BooruType.e621: '/posts.json?limit=1',
    BooruType.sankaku: '/post/index.json?limit=1',
    BooruType.zerochan: '/?json=1',
    BooruType.gelbooruV2: '/index.php?page=dapi&s=post&q=index&json=1&limit=1',
    BooruType.rule34: '/index.php?page=dapi&s=post&q=index&json=1&limit=1',
    BooruType.safebooru: '/index.php?page=dapi&s=post&q=index&json=1&limit=1',
    // paheal 系：图库首页（老分支没有 JSON 接口，用列表页探活）
    BooruType.shimmie2: '/post/list/1',
    // 视频站（KVS）：最新更新页
    BooruType.kvs: '/latest-updates/1/',
  };

  /// 探测时的响应体特征校验。
  ///
  /// 只看状态码会把站点判错：实测 safebooru.org 的 `/?json=1` 返回 200
  /// （HTML 首页），排在前面的 zerochan 因此会把 safebooru 认成自己。
  /// 这里对每个类型补一个「响应里应该有这个」的特征。
  static const _probeSignatures = <BooruType, String>{
    BooruType.danbooru: '"id"',
    BooruType.moebooru: '"id"',
    BooruType.e621: '"posts"',
    BooruType.sankaku: '"id"',
    BooruType.zerochan: '"items"',
    BooruType.gelbooruV2: '<post',
    BooruType.rule34: '<post',
    BooruType.safebooru: '<post',
    BooruType.shimmie2: '/post/view/',
    BooruType.kvs: '/videos/',
  };

  Future<BooruType?> probe(String baseUrl, {BooruType? singleType}) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final dio = DioFactory.createProbe(hostsInterceptor: hostsInterceptor);

    // 先按域名判：命中的话根本不用发请求（也避免把 safebooru.org 认成 zerochan
    // ——它的 /?json=1 确实返回 200，只看状态码必然误判）。
    if (singleType == null) {
      final byDomain = scanner(url);
      if (byDomain != null) return byDomain;
    }

    final types = singleType != null ? [singleType] : _probePaths.keys;
    for (final type in types) {
      final path = _probePaths[type];
      if (path == null) continue;
      try {
        final response = await dio.get('$url$path');
        if (response.statusCode != 200) continue;
        // 状态码之外还要看响应体特征：证不了自己的类型不算命中。
        final signature = _probeSignatures[type];
        if (signature == null) return type;
        final body = response.data?.toString() ?? '';
        if (body.contains(signature)) return type;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  BooruType? scanner(String url) {
    final lower = url.toLowerCase();
    final defaultUrls = <BooruType, String>{
      BooruType.danbooru: 'danbooru.donmai.us',
      BooruType.gelbooruV2: 'gelbooru.com',
      BooruType.moebooru: 'yande.re',
      BooruType.e621: 'e621.net',
      BooruType.sankaku: 'sankakucomplex.com',
      BooruType.zerochan: 'zerochan.net',
      BooruType.rule34: 'rule34.xxx',
      BooruType.safebooru: 'safebooru.org',
      // rule34 家族与视频站
      BooruType.shimmie2: 'paheal.net',
      BooruType.kvs: 'rule34video.com',
    };
    for (final entry in defaultUrls.entries) {
      if (lower.contains(entry.value)) return entry.key;
    }
    return null;
  }

  bool isRegistered(BooruType type) => _factories.containsKey(type);

  List<BooruType> get registeredTypes => _factories.keys.toList();

  Dio createDio(BooruType type,
      {String? baseUrl, String? login, String? apiKey}) {
    final engine = get(type);
    if (engine == null) throw Exception('Engine not registered: $type');

    final headers = Map<String, dynamic>.from(engine.booru.defaultHeaders);

    if (login != null && apiKey != null) {
      final basic = base64Encode(utf8.encode('$login:$apiKey'));
      headers['Authorization'] = 'Basic $basic';
    }

    final dio = DioFactory.create(
      baseUrl: baseUrl ?? engine.booru.baseUrl,
      headers: headers,
      hostsInterceptor: hostsInterceptor,
    );
    // 凭据的注入方式因站而异：danbooru / e621 认 HTTP Basic（上面已写成头），
    // gelbooru / rule34 / safebooru 认 query 参数 api_key + user_id。
    // 把凭据放进 options.extra，由引擎按自己的方式取用——此前只发 Basic，
    // 那三个站即使用户填了凭据也永远 401。
    dio.options.extra = <String, dynamic>{
      if (login != null && login.isNotEmpty) 'authLogin': login,
      if (apiKey != null && apiKey.isNotEmpty) 'authApiKey': apiKey,
    };
    return dio;
  }

  BooruRepository createRepository(BooruType type,
      {String? baseUrl, String? serverId, String? login, String? apiKey}) {
    final engine = get(type);
    if (engine == null) throw Exception('Engine not registered: $type');
    final dio = createDio(type, baseUrl: baseUrl, login: login, apiKey: apiKey);
    return engine.repositoryFactory(dio, serverId: serverId);
  }
}
