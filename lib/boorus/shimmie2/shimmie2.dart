import 'package:boorunova/boorus/engine/booru.dart';
import 'package:boorunova/boorus/engine/booru_capabilities.dart';
import 'package:boorunova/boorus/engine/booru_type.dart';

/// Shimmie2 / paheal 系图站（rule34.paheal.net 等）。
///
/// 与 gelbooru DAPI 不同族：接口是图库 HTML 页（老分支）或新版 JSON 接口，
/// 由 [Shimmie2Repository] 两条路都试。
class Shimmie2 extends Booru {
  const Shimmie2();

  @override
  BooruType get type => BooruType.shimmie2;

  @override
  String get id => 'shimmie2';

  @override
  String get name => 'Shimmie2';

  @override
  String get baseUrl => 'https://rule34.paheal.net';

  @override
  BooruCapabilities get capabilities => const BooruCapabilities();

  @override
  Map<String, String> get defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/json',
      };

  @override
  String? get loginUrl => null;
}
