/// 引擎能力声明：控制 UI 显隐，避免给不支持的站点展示入口。
///
/// 字段只保留真正被消费的那些。历史上这里有 11 个字段，其中
/// comments / notes / voting / characterPages / videoSupport /
/// tagTranslation / syntaxHighlighting / bulkDownload 八个零消费点——
/// 声明了但没有任何 UI 读它们。留着会让人误以为这些能力已经接好，
/// 也让「这个引擎到底支持什么」变得无法一眼读完。
class BooruCapabilities {
  const BooruCapabilities({
    this.pools = false,
  });

  /// 支持图集（fetchPools 有实现）。唯一有 UI 消费点的字段。
  final bool pools;
}
