import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:flutter/material.dart';

class BooruSiteTemplate {
  const BooruSiteTemplate({
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.icon,
    required this.color,
    this.description,
  });

  final String name;
  final BooruType type;
  final String baseUrl;
  final IconData icon;
  final MaterialColor color;
  final String? description;

  static const List<BooruSiteTemplate> all = [
    BooruSiteTemplate(
      name: 'Danbooru',
      type: BooruType.danbooru,
      baseUrl: 'https://danbooru.donmai.us',
      icon: Icons.photo_library,
      color: Colors.blue,
      description: 'danbooru.donmai.us',
    ),
    BooruSiteTemplate(
      name: 'Gelbooru',
      type: BooruType.gelbooruV2,
      baseUrl: 'https://gelbooru.com',
      icon: Icons.image,
      color: Colors.orange,
      description: 'gelbooru.com',
    ),
    BooruSiteTemplate(
      name: 'Safebooru',
      type: BooruType.safebooru,
      baseUrl: 'https://safebooru.org',
      icon: Icons.shield,
      color: Colors.green,
      description: 'safebooru.org',
    ),
    BooruSiteTemplate(
      name: 'yande.re',
      type: BooruType.moebooru,
      baseUrl: 'https://yande.re',
      icon: Icons.auto_awesome,
      color: Colors.pink,
      description: 'yande.re / konachan.com',
    ),
    BooruSiteTemplate(
      name: 'Konachan',
      type: BooruType.moebooru,
      baseUrl: 'https://konachan.com',
      icon: Icons.auto_awesome,
      color: Colors.purple,
      description: 'konachan.com',
    ),
    BooruSiteTemplate(
      name: 'e621',
      type: BooruType.e621,
      baseUrl: 'https://e621.net',
      icon: Icons.pets,
      color: Colors.brown,
      description: 'e621.net',
    ),
    BooruSiteTemplate(
      name: 'Sankaku',
      type: BooruType.sankaku,
      baseUrl: 'https://chan.sankakucomplex.com',
      icon: Icons.lens_blur,
      color: Colors.red,
      description: 'chan.sankakucomplex.com',
    ),
    BooruSiteTemplate(
      name: 'Zerochan',
      type: BooruType.zerochan,
      baseUrl: 'https://www.zerochan.net',
      icon: Icons.filter_vintage,
      color: Colors.teal,
      description: 'zerochan.net',
    ),
    BooruSiteTemplate(
      name: 'Rule 34',
      type: BooruType.rule34,
      baseUrl: 'https://api.rule34.xxx',
      icon: Icons.warning_amber,
      color: Colors.deepOrange,
      description: 'api.rule34.xxx',
    ),
    // ---- rule34 家族：同族镜像（gelbooru DAPI 协议，与 Safebooru 同一引擎）----
    BooruSiteTemplate(
      name: 'Xbooru',
      type: BooruType.gelbooruV2,
      baseUrl: 'https://xbooru.com',
      icon: Icons.grid_view,
      color: Colors.pink,
      description: 'xbooru.com',
    ),
    BooruSiteTemplate(
      name: 'Realbooru',
      type: BooruType.gelbooruV2,
      baseUrl: 'https://realbooru.com',
      icon: Icons.photo_camera_back,
      color: Colors.deepPurple,
      description: 'realbooru.com',
    ),
    BooruSiteTemplate(
      name: 'TBIB',
      type: BooruType.gelbooruV2,
      baseUrl: 'https://tbib.org',
      icon: Icons.collections_bookmark,
      color: Colors.brown,
      description: 'tbib.org',
    ),
    BooruSiteTemplate(
      name: 'Rule34.us',
      type: BooruType.gelbooruV2,
      baseUrl: 'https://rule34.us',
      icon: Icons.link,
      color: Colors.amber,
      description: 'rule34.us',
    ),
    // ---- rule34 家族：paheal 系（Shimmie2，接口是图库 HTML/新版 JSON）----
    BooruSiteTemplate(
      name: 'Rule 34 Paheal',
      type: BooruType.shimmie2,
      baseUrl: 'https://rule34.paheal.net',
      icon: Icons.photo_library_outlined,
      color: Colors.red,
      description: 'rule34.paheal.net',
    ),
    BooruSiteTemplate(
      name: 'AllGirls (Paheal)',
      type: BooruType.shimmie2,
      baseUrl: 'https://allgirls.paheal.net',
      icon: Icons.photo_library,
      color: Colors.pink,
      description: 'allgirls.paheal.net',
    ),
    // ---- 视频站（KVS 家族：列表是 HTML，播放地址按需解析）----
    BooruSiteTemplate(
      name: 'Rule34 Video',
      type: BooruType.kvs,
      baseUrl: 'https://rule34video.com',
      icon: Icons.play_circle_outline,
      color: Colors.red,
      description: 'rule34video.com · 视频',
    ),
    // 其他 KVS 站：选这个模板后把域名改成目标站即可（同 CMS 的站点成百上千，
    // 枚举不完）。这里不放开「空域名」条目——引导页会直接按模板建服务器，
    // 空 baseUrl 会造出一个打不开的站点。
  ];

  /// 尚未实现引擎的站点模板。
  ///
  /// 它们从 [all] 里移出来：此前引导页与添加入口会列出 anime-pictures /
  /// e-shuushuu，而这两个类型没有注册任何引擎——用户勾选后只会得到一个
  /// 「引擎不可用」的服务器。类型本身留在枚举里，已有服务器不受影响。
  /// 实现引擎后把条目移回 [all] 即可。
  static const List<BooruSiteTemplate> planned = [
    BooruSiteTemplate(
      name: 'Anime-Pictures',
      type: BooruType.animePictures,
      baseUrl: 'https://anime-pictures.net',
      icon: Icons.palette,
      color: Colors.indigo,
      description: 'anime-pictures.net',
    ),
    BooruSiteTemplate(
      name: 'E-Shuushuu',
      type: BooruType.eshuushuu,
      baseUrl: 'https://e-shuushuu.net',
      icon: Icons.collections,
      color: Colors.cyan,
      description: 'e-shuushuu.net',
    ),
  ];

  static BooruSiteTemplate? findByType(BooruType type) {
    try {
      return all.firstWhere((t) => t.type == type);
    } catch (_) {
      return null;
    }
  }
}
