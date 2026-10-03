# 站点家族覆盖与视频站接入

## 一、当前已注册的引擎（10 个）

| 引擎 | 类型 | 覆盖的站点 | 协议 |
|---|---|---|---|
| Danbooru | `danbooru` | danbooru.donmai.us 及其克隆 | `/posts.json` |
| Gelbooru V2 | `gelbooru_v2` | gelbooru.com、**safebooru.org、xbooru.com、realbooru.com、tbib.org、rule34.us** | DAPI XML |
| Moebooru | `moebooru` | yande.re、konachan.com | `/post.json` |
| e621 | `e621` | e621.net | `/posts.json` |
| Sankaku | `sankaku` | chan.sankakucomplex.com | `/post/index.json` |
| Zerochan | `zerochan` | zerochan.net | `/<tags>?json=1` |
| Rule34 | `rule34` | api.rule34.xxx | DAPI JSON |
| Safebooru | `safebooru` | safebooru.org | DAPI XML |
| **Shimmie2** | `shimmie2` | **rule34.paheal.net、allgirls.paheal.net** | 图库 HTML / 新版 JSON API |
| **KVS（视频）** | `kvs` | **rule34video.com** 及同 CMS 的视频站 | 列表 HTML + 详情页 flashvars |

Gelbooru V2 一行覆盖 6 个站点：它们是同一套 DAPI 协议，只有域名不同，
模板里各列一条即可（协议一致性已在 safebooru 上实测：`<posts count offset>`、
`pid` 0 基、`rating:safe` 可用而 `rating:s` 命中 0 条）。

## 二、视频站的接入方式（KVS 家族）

与图站的根本差别：**列表页只有缩略图，播放地址在详情页的播放器配置里**。
因此：

1. 列表：解析 `/videos/<id>/<slug>/` 链接，取缩略图、时长；标签从 slug 与
   标题反推（视频站不提供标签字段）。
2. 播放：打开时才调 `BooruRepository.resolvePlaybackUrl(postUrl)` 抓详情页，
   从 `flashvars` 解出 `video_url` / `video_alt_url` / `video_alt_url2`；
   解不到就在整页里找 `mp4|webm|m3u8|mpd` 直链。
3. 挑地址的优先级：**mp4 优先于流清单**——mp4 能播也能存，HLS 只能播。
4. 播放器：`VideoViewer` 走 `video_player`，Android ExoPlayer / iOS AVPlayer
   **原生支持 HLS**，所以只有 m3u8 的站点也能播。
5. 下载：`.m3u8/.mpd` 是播放列表不是文件，下载层**明确拒绝**并给出可读原因
   （否则会往相册写一个几十字节的文本）。
6. 其它 KVS 站：选「Rule34 Video」模板，把域名改成目标站即可（同 CMS 的站点
   成百上千，靠模板枚举不现实）。域名改了之后「探测」页也能识别。

## 三、真机核验（必做一次）

本项目的开发环境对这批域名做了 DNS 污染（`rule34.xxx`、`rule34video.com` 等
都被解析到 Facebook 段的假 IP，连接直接失败），因此 **Shimmie2 与 KVS 两个
引擎的解析逻辑是按家族结构实现 + 合成固件测试的，尚未对真实站点验证过**。
在能访问这些站点的网络上按下面三条核一遍即可：

| 检查 | 做法 | 期望 |
|---|---|---|
| 站点识别 | 「服务器 → 添加 → 探测」，输入 `https://rule34video.com` | 识别为 `kvs`；paheal 识别为 `shimmie2` |
| 列表 | 添加该站点后打开首页 | 出现视频缩略图网格；点开一个进入播放器 |
| 播放 | 播放器内点击 | 能播（mp4 或 HLS）；失败时显示「视频无法播放」+ 重试，而不是一直转圈 |

若列表为空而浏览器能打开该站，多半是列表页 DOM 与家族惯例有差异：把
列表页 HTML 的**结构片段**（去掉内容本身）贴进 issue，按 `KvsParser.parseList`
的链接正则调整即可——解析全部写成容错的，坏一条不会影响整页。

## 四、新增一个站点需要改哪些地方

1. `lib/boorus/engine/booru_type.dart`：枚举加一项（同一协议家族的克隆**不用**加，复用现有类型）。
2. `lib/boorus/<家族>/`：`xxx.dart`（Booru 元数据）+ `xxx_repository.dart` + `parser/xxx_parser.dart`。
3. `lib/boorus/engine/registry.dart`：`_registerDefaults` 注册 + `_probePaths` 探测路径 + `_probeSignatures` 响应体特征 + `scanner` 域名表。
4. `lib/presentation/screens/server/booru_site_template.dart`：加模板（同名协议家族直接复用类型）。
5. `test/boorus/`：解析器固件测试。

> 只有 1–2 步是本模板必须的：3、4、5 目前仍需手写。把站点元数据收敛成一张
> `BooruSiteDescriptor`（域名、探测路径与特征、模板、域名表同源）可以把 3、4
> 变成自动派生——这是下一步的收敛方向。
