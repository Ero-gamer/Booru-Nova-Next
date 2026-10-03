/// 全应用文案（中 / 英双语）。
///
/// 所有 getter 按 [T.isEn] 返回对应语言。切换语言时除了更新
/// [T.isEn]，必须让整棵组件树重建才会刷新——BooruNova 在
/// MaterialApp 上以 locale 作为 key 强制整体重建。
/// 注意：因为返回值不再是编译期常量，包含 `T.x` 的 `const` 表达式
/// 一律不能再加 const。
class T {
  T._();

  /// 当前是否英文。由 AppSettings.language 驱动，启动与切换时赋值。
  static bool isEn = false;

  static void setLocale(String languageCode) {
    isEn = languageCode.startsWith('en');
  }

  // App
  static String get appTitle => _t('BooruNova', 'BooruNova');

  // 启动失败降级页（Hive 打不开时唯一能显示的界面，不能依赖任何 provider）
  static String get bootFailedTitle => _t('本地数据打不开', 'Local data unavailable');
  static String get bootFailedHint => _t(
      '应用数据文件可能已损坏或被占用。可尝试重启应用；若仍无法启动，请在系统设置里清除应用数据后重新添加站点。',
      'The app data files may be corrupted or locked. Try restarting; if it still fails, clear app data in system settings and add your sites again.');
  static String get recoveredDataHint => _t(
      '检测到本地数据损坏，已隔离损坏文件并重建（原文件保留在应用目录，后缀 .corrupt）。',
      'Local data was corrupted. The damaged file was quarantined (.corrupt suffix) and storage was rebuilt.');

  // Onboarding
  static String get obWelcome => _t('欢迎使用 BooruNova', 'Welcome to BooruNova');
  static String get obWelcomeSubtitle => _t(
      '一个应用，浏览所有 Booru 图站。先选择语言，再添加你想浏览的站点。',
      'One app for every booru. Pick a language, then add the sites you want to browse.');
  static String get obChooseLanguage => _t('选择语言', 'Choose language');
  static String get obChooseSites => _t('添加站点', 'Add sites');
  static String get obChooseSitesSubtitle => _t(
      '勾选想浏览的站点，之后可以随时在「服务器」中添加或删除。',
      'Pick the sites you want to browse. You can add or remove more later in Servers.');
  static String get obSiteAuthNote => _t(
      '部分站点（如 Gelbooru / Rule34）之后需要在其编辑页填写 API Key 才能使用图集等功能。',
      'Some sites (e.g. Gelbooru / Rule34) need an API Key later in their editor for pools and more.');
  static String get obStart => _t('开始使用', 'Get started');
  static String get obSkip => _t('跳过', 'Skip');
  static String get obNext => _t('下一步', 'Next');
  static String get langZhName => _t('简体中文', '简体中文');
  static String get langZhSub => _t('当前语言', 'Current language');
  static String get langEnName => _t('English', 'English');
  static String get langEnSub => _t('切换界面语言', 'Switch UI language');

  // Home
  static String get searchHint => _t('搜索...', 'Search...');
  static String get tapToSearch => _t('点击搜索', 'Tap to search');
  static String get noPostsYet => _t('暂无帖子', 'No posts yet');
  static String get noSearchResults => _t('没有找到帖子', 'No posts found');
  static String get addBooruServer =>
      _t('添加一个 Booru 服务器开始浏览', 'Add a booru server to start browsing');
  static String get addServer => _t('添加服务器', 'Add server');
  static String get tryDifferentSearch =>
      _t('换一个关键词试试，或清除筛选条件', 'Try another keyword or clear the filters');
  static String get engineNotAvailable => _t('引擎不可用：', 'Engine unavailable: ');
  static String get switchServerTip => _t('点击切换站点', 'Tap to switch site');
  static String get onlyOneServerHint =>
      _t('只有一个站点，先去添加更多站点吧', 'Only one site so far. Add more to switch between them.');
  static String get favorites => _t('收藏', 'Favorites');
  static String get history => _t('历史', 'History');
  static String get settings => _t('设置', 'Settings');
  static String get servers => _t('服务器', 'Servers');
  static String get downloads => _t('下载', 'Downloads');
  static String get results => _t('结果', 'results');
  static String get selected => _t('已选', 'selected');
  static String get selectAll => _t('全选', 'Select all');
  static String get clear => _t('清除', 'Clear');
  static String get clearFilters => _t('清除筛选', 'Clear filters');
  static String get filters => _t('筛选', 'Filters');
  static String get sortBy => _t('排序方式', 'Sort by');
  static String get ratingFilter => _t('分级筛选', 'Rating filter');
  static String get all => _t('全部', 'All');
  static String get safe => _t('安全', 'Safe');
  static String get questionable => _t('可疑', 'Questionable');
  static String get explicit => _t('限制级', 'Explicit');
  static String get sortColon => _t('排序：', 'Sort: ');
  static String get ratingColon => _t('分级：', 'Rating: ');

  // Drawer (end drawer explore features)
  static String get blacklist => _t('黑名单', 'Blacklist');
  static String get blacklistSub => _t('屏蔽标签管理', 'Manage blocked tags');
  static String get explore => _t('探索', 'Explore');
  static String get pools => _t('图集', 'Pools');


  // Search Bar
  static String get sortRelevance => _t('相关度', 'Relevance');
  static String get sortScore => _t('分数', 'Score');
  static String get sortDate => _t('日期', 'Date');
  static String get sortRating => _t('分级', 'Rating');

  // Post Viewer
  static String get share => _t('分享', 'Share');
  static String get savedToGallery => _t('已保存到相册', 'Saved to gallery');
  static String get downloadFailed => _t('下载失败', 'Download failed');
  static String get postDetails => _t('帖子详情', 'Post details');
  static String get stopSlideshow => _t('停止自动切换', 'Stop slideshow');
  static String get autoSlideshow => _t('自动切换', 'Auto slideshow');
  static String get videoPlayFailed =>
      _t('视频无法播放', 'This video cannot be played');
  static String get streamCannotSave =>
      _t('该视频只有流地址，无法保存到相册', 'Stream-only video cannot be saved');

  // Post Detail
  static String get score => _t('分数', 'Score');
  static String get rating => _t('分级', 'Rating');
  static String get size => _t('尺寸', 'Dimensions');
  static String get source => _t('来源', 'Source');
  static String get postUrl => _t('帖子链接', 'Post link');
  static String get tags => _t('标签', 'Tags');
  static String get openFullViewer => _t('打开全屏查看', 'Open full viewer');
  static String get blockTagsDone => _t('已屏蔽标签', 'Tags blocked');
  static String get copiedTags => _t('已复制标签', 'Tags copied');
  static String get searchAction => _t('搜索', 'Search');
  static String get appendAction => _t('追加', 'Append');
  static String get blockAction => _t('屏蔽', 'Block');
  static String get copyAction => _t('复制', 'Copy');

  // Favorites
  static String get noFavoritesYet => _t('还没有收藏', 'No favorites yet');
  static String get tapHeartToSave =>
      _t('在查看器中点击心形图标收藏帖子', 'Tap the heart in the viewer to save posts');

  // History
  static String get clearHistory => _t('清除历史', 'Clear history');
  static String get clearHistoryTitle => _t('清除浏览历史？', 'Clear browsing history?');
  static String get clearHistoryContent =>
      _t('这将删除所有浏览记录。', 'This will delete all browsing history.');
  static String get noHistory => _t('暂无浏览历史', 'No browsing history');
  static String get historyHint =>
      _t('看过的帖子会出现在这里，点一下就能回到那张图', 'Posts you have viewed show up here. Tap one to go back to it.');
  static String get browseNow => _t('去逛逛', 'Browse now');
  static String get justNow => _t('刚刚', 'just now');
  static String get minutesAgo => _t('分钟前', 'm ago');
  static String get hoursAgo => _t('小时前', 'h ago');
  static String get daysAgo => _t('天前', 'd ago');
  static String get cancel => _t('取消', 'Cancel');

  // Downloads
  static String get clearDownloadHistory => _t('清除下载历史', 'Clear download history');
  static String get clearDownloadHistoryTitle =>
      _t('清除下载历史？', 'Clear download history?');
  static String get clearDownloadHistoryContent => _t(
      '删除下载历史记录，已下载的图片仍保留在相册中。',
      'Deletes the download log. Images already saved stay in your gallery.');
  static String get downloadsHint =>
      _t('下载过的图会列在这里，点一下可以预览', 'Downloaded images show up here. Tap one to preview.');
  static String get openFile => _t('用其他应用打开', 'Open with another app');
  static String get fileUnavailable =>
      _t('文件已不存在，可能被系统清理了', 'File is gone. It may have been cleaned up by the system.');
  static String get removedFromDownloads =>
      _t('已从下载记录中移除', 'Removed from downloads');
  static String get noDownloadsYet => _t('还没有下载', 'No downloads yet');
  static String get tapDownloadToSave =>
      _t('在查看器中点击下载按钮保存图片', 'Tap the download button in the viewer to save images');

  // Batch
  static String get downloadSelected => _t('下载选中', 'Download selected');
  static String get favoriteSelected => _t('收藏选中', 'Favorite selected');
  static String get shareSelected => _t('分享选中', 'Share selected');
  static String get clearSelection => _t('清除选择', 'Clear selection');
  static String get downloadedCount => _t('已下载', 'Downloaded');
  static String get ofImages => _t('张图片', 'images');
  static String get addedToFavorites => _t('已添加到收藏', 'Added to favorites');

  // Settings - main page
  static String get sectionGeneral => _t('通用', 'General');
  static String get sectionBrowsing => _t('浏览', 'Browsing');
  static String get sectionData => _t('数据', 'Data');
  static String get sectionServer => _t('服务器', 'Servers');
  static String get sectionOther => _t('其他', 'Other');
  static String get appearanceSub => _t('主题、颜色', 'Theme, colors');
  static String get language => _t('语言', 'Language');
  static String get languageSub => _t('界面语言', 'UI language');
  static String get viewerEntry => _t('图片查看器', 'Image viewer');
  static String get viewerEntrySub => _t('滑动、幻灯片、视频', 'Swipe, slideshow, video');
  static String get gestures => _t('手势', 'Gestures');
  static String get gesturesSub => _t('滑动、点击、长按动作', 'Swipe, tap and long-press actions');
  static String get searchEntry => _t('搜索', 'Search');
  static String get searchEntrySub => _t('搜索选项、过滤', 'Search options, filters');
  static String get searchHistoryEntry => _t('搜索历史', 'Search history');
  static String get searchHistoryEntrySub => _t('查看管理搜索记录', 'View and manage search history');
  static String get downloadEntry => _t('下载', 'Download');
  static String get downloadEntrySub => _t('下载路径、质量', 'Download path, quality');
  static String get dataAndStorage => _t('数据与存储', 'Data & storage');
  static String get dataAndStorageSub => _t('缓存管理、存储空间', 'Cache management, storage');
  static String get backup => _t('备份恢复', 'Backup & restore');
  static String get backupSub => _t('导出/导入数据', 'Export / import data');
  static String get serverManage => _t('服务器管理', 'Server management');
  static String get serverManageSub => _t('添加、编辑、排序', 'Add, edit, reorder');
  static String get hostsEntrySub => _t('自定义域名映射', 'Custom domain mapping');

  // Appearance
  static String get themeMode => _t('主题模式', 'Theme mode');
  static String get accentColor => _t('主题色', 'Accent color');
  static String get reduceAnimations => _t('减少动画', 'Reduce animations');
  static String get reduceAnimationsSub =>
      _t('提升低端设备流畅度', 'Better performance on low-end devices');
  static String get modeSystem => _t('系统', 'System');
  static String get modeLight => _t('浅色', 'Light');
  static String get modeDark => _t('深色', 'Dark');
  static String get modeMidnight => _t('午夜', 'Midnight');

  // Viewer settings
  static String get sectionSwipe => _t('滑动', 'Swipe');
  static String get horizontalSwipe => _t('水平滑动', 'Horizontal swipe');
  static String get horizontalSwipeSub =>
      _t('关闭则使用垂直滑动切换图片', 'When off, swipe vertically to switch images');
  static String get sectionSlideshow => _t('幻灯片', 'Slideshow');
  static String get autoInterval => _t('自动播放间隔', 'Auto-advance interval');
  static String get seconds => _t('秒', 's');
  static String get increase => _t('增加', 'Increase');
  static String get decrease => _t('减少', 'Decrease');

  // Gestures
  static String get sectionViewer => _t('图片查看器', 'Image viewer');
  static String get swipeDownAction => _t('下滑动作', 'Swipe down');
  static String get tapAction => _t('单击图片', 'Single tap');
  static String get doubleTapAction => _t('双击图片', 'Double tap');
  static String get addedToFavoritesShort => _t('已收藏', 'Added to favorites');
  static String get removedFromFavorites => _t('已取消收藏', 'Removed from favorites');
  static String get swipeDownNeedsHorizontal =>
      _t('仅在「横向翻页」模式下生效', 'Only applies in horizontal paging mode');
  static String get longPressAction => _t('长按图片', 'Long press');
  static String get actionClose => _t('关闭', 'Close');
  static String get actionDetail => _t('查看详情', 'View details');
  static String get actionNone => _t('无', 'None');
  static String get actionFav => _t('收藏', 'Favorite');
  static String get actionZoom => _t('缩放', 'Zoom');

  // Language page
  static String get currentLanguage => _t('当前语言', 'Current language');

  // Search settings
  static String get sectionTagSuggest => _t('标签建议', 'Tag suggestions');
  static String get suggestionCount => _t('建议标签数量', 'Suggestion count');
  static String get countUnit => _t('个', '');

  // Data storage
  static String get sectionCache => _t('缓存', 'Cache');
  static String get sectionRecords => _t('记录', 'Records');
  static String get cache => _t('缓存', 'Cache');
  static String get imageCache => _t('图片缓存', 'Image cache');
  static String get calculating => _t('计算中...', 'Calculating...');
  static String get unknown => _t('未知', 'Unknown');
  static String get recordsUnit => _t('条记录', 'records');
  static String get filesUnit => _t('个文件', 'files');
  static String get imagesUnit => _t('张', ' images, ');
  static String get clearedCacheFiles => _t('已清除 ', 'Cleared ');
  static String get browsingHistory => _t('浏览历史', 'Browsing history');
  static String get downloadHistory => _t('下载历史', 'Download history');
  static String get clearAction => _t('清除', 'Clear');

  // Download settings
  static String get sectionQuality => _t('质量', 'Quality');
  static String get sectionPath => _t('路径', 'Path');
  static String get downloadQuality => _t('下载质量', 'Download quality');
  static String get qualitySample => _t('预览', 'Sample');
  static String get qualityOriginal => _t('原图', 'Original');
  static String get downloadPath => _t('下载路径', 'Download path');
  static String get defaultPathPrefix => _t('默认: ', 'Default: ');
  static String get resetDefaultPath => _t('重置为默认路径', 'Reset to default path');
  static String get downloadSettingsTitle => _t('下载设置', 'Download settings');

  // Search history page
  static String get searchHistoryTitle => _t('搜索历史', 'Search history');
  static String get noSearchHistory => _t('暂无搜索历史', 'No search history');
  static String get searchHistoryHint =>
      _t('在首页搜索过的关键词会出现在这里', 'Keywords you search on the home page appear here');
  static String get clearSearchHistoryTip => _t('清空搜索历史', 'Clear search history');
  static String get deleteAction => _t('删除', 'Delete');

  // Backup
  static String get backupTitle => _t('数据备份恢复', 'Backup & restore');
  static String get backupContentHeader => _t('备份内容', 'Backup content');
  static String get serversCountUnit => _t(' 个', '');
  static String get exportBackup => _t('导出备份', 'Export backup');
  static String get exportBackupSub => _t('保存为 JSON 文件', 'Save as JSON file');
  static String get importBackup => _t('导入备份', 'Import backup');
  static String get importBackupSub => _t('从 JSON 文件恢复', 'Restore from a JSON file');
  static String get backupImported => _t('备份已导入', 'Backup imported');
  static String get importFailed => _t('导入失败', 'Import failed');
  static String get exportFailed => _t('导出失败', 'Export failed');
  static String get exportedTo => _t('已导出: ', 'Exported: ');

  // Privacy
  static String get privacyTitle => _t('隐私', 'Privacy');
  static String get sectionDataManage => _t('数据管理', 'Data management');
  static String get clearSearchHistory => _t('清除搜索历史', 'Clear search history');
  static String get clearSearchHistorySub =>
      _t('删除所有搜索关键词记录', 'Delete all saved search keywords');
  static String get clearViewHistory => _t('清除浏览历史', 'Clear browsing history');
  static String get clearViewHistorySub => _t('删除所有浏览记录', 'Delete all viewing history');
  static String get clearDownloadRecords => _t('清除下载记录', 'Clear download records');
  static String get clearDownloadRecordsSub => _t(
      '删除下载历史（已保存的图片不受影响）',
      'Delete the download log (saved images are not affected)');
  static String get sectionPrivacyNote => _t('隐私声明', 'Privacy notes');
  static String get dataCollection => _t('数据收集', 'Data collection');
  static String get dataCollectionSub => _t(
      'BooruNova 不会收集或上传任何个人信息。所有数据（设置、收藏、历史记录）仅存储在本地设备中。',
      'BooruNova never collects or uploads personal data. Everything (settings, favorites, history) stays on this device.');
  static String get networkRequests => _t('网络请求', 'Network requests');
  static String get networkRequestsSub => _t(
      '仅在你主动浏览、搜索和下载时向 Booru 服务器发起请求，不会连接第三方分析或追踪服务。',
      'Requests are only made to booru servers when you browse, search or download. No third-party analytics or tracking.');
  static String get searchHistoryCleared =>
      _t('搜索历史已清除', 'Search history cleared');
  static String get viewHistoryCleared => _t('浏览历史已清除', 'Browsing history cleared');
  static String get downloadRecordsCleared =>
      _t('下载记录已清除', 'Download records cleared');

  // Settings
  static String get appearance => _t('外观', 'Appearance');
  static String get theme => _t('主题', 'Theme');
  static String get defaultServer => _t('默认服务器', 'Default server');
  static String get defaultServerSubtitle =>
      _t('启动时默认加载的服务器', 'Server loaded on startup');
  static String get chooseTheme => _t('选择主题', 'Choose theme');
  static String get system => _t('跟随系统', 'System');
  static String get light => _t('浅色', 'Light');
  static String get dark => _t('深色', 'Dark');
  static String get midnight => _t('午夜', 'Midnight');
  static String get noneAutoSelect => _t('无（自动选择第一个）', 'None (first one automatically)');
  static String get hosts => _t('Hosts', 'Hosts');
  static String get useCustomHosts => _t('使用自定义 Hosts', 'Use custom hosts');
  static String get useCustomHostsSubtitle =>
      _t('将 Booru 域名指向自定义 IP', 'Point booru domains to custom IPs');
  static String get manageHostMappings => _t('管理 Host 映射', 'Manage host mappings');
  static String get manageHostMappingsSubtitle =>
      _t('添加、编辑或删除 Host 条目', 'Add, edit or remove host entries');
  static String get dataManagement => _t('数据管理', 'Data management');
  static String get clearCache => _t('清除缓存', 'Clear cache');
  static String get clearCacheSubtitle => _t('删除已下载的图片缩略图', 'Delete downloaded thumbnails');
  static String get about => _t('关于', 'About');
  static String get aboutSub => _t('版本信息、开源许可', 'Version info, license');
  static String get privacyEntrySub => _t('隐私设置', 'Privacy settings');
  static String get openSource => _t('开源协议', 'License');
  static String get tempFiles => _t(' 个临时文件', ' temp files');
  static String get historyCleared => _t('历史已清除', 'History cleared');
  static String get downloadHistoryCleared =>
      _t('下载历史已清除', 'Download history cleared');

  // Server Page
  static String get noServersAdded => _t('还没有添加服务器', 'No servers added');
  static String get addBooruSite =>
      _t('添加一个 Booru 站点开始浏览图片', 'Add a booru site to start browsing');
  static String get myServers => _t('我的服务器', 'My servers');
  static String get popularSites => _t('热门站点', 'Popular sites');
  static String get removeServer => _t('删除服务器？', 'Remove server?');
  static String get deleteConfirm => _t('确认删除"', 'Remove "');
  static String get deleteConfirmEnd => _t('？此操作不可撤销。', '"? This cannot be undone.');
  static String get delete => _t('删除', 'Delete');
  static String get edit => _t('编辑', 'Edit');
  static String get editServer => _t('编辑服务器', 'Edit server');
  static String get addNewServer => _t('添加服务器', 'Add server');
  static String get serverName => _t('服务器名称', 'Server name');
  static String get serverNameHint => _t('我的 Danbooru', 'My Danbooru');
  static String get serverUrl => _t('服务器地址', 'Server URL');
  static String get serverUrlHint => _t('https://danbooru.donmai.us', 'https://danbooru.donmai.us');
  static String get engineType => _t('引擎类型', 'Engine type');
  static String get searchTagHint => _t('搜索标签...', 'Search tags...');
  static String get required => _t('必填', 'Required');
  static String get authenticationOptional =>
      _t('身份验证（可选）', 'Authentication (optional)');
  static String get apiKey => _t('API Key', 'API Key');
  static String get apiKeyHint => _t('如不需要请留空', 'Leave empty if not needed');
  static String get login => _t('登录名 / 用户名', 'Login / username');
  static String get loginHint => _t('如不需要请留空', 'Leave empty if not needed');
  static String get saveChanges => _t('保存修改', 'Save changes');
  static String get addServerBtn => _t('添加服务器', 'Add server');
  static String get addSite => _t('添加站点', 'Add site');
  static String get engineMatchResults => _t('引擎匹配结果', 'Engine match results');
  static String get confirmAdd => _t('确认添加', 'Confirm');
  static String get enterUrlToMatch =>
      _t('输入站点地址自动匹配引擎', 'Enter a site URL to auto-match the engine');
  static String get urlHint => _t('https://safebooru.org', 'https://safebooru.org');
  static String get reorder => _t('排序', 'Reorder');
  static String get done => _t('完成', 'Done');
  static String get addedTag => _t('已添加', 'Added');

  // Server probe / scan
  static String get scanTitle => _t('服务器探测', 'Server probe');
  static String get scanCancel => _t('取消', 'Cancel');
  static String get scanContinue => _t('继续', 'Continue');
  static String get scanStart => _t('探测', 'Probe');
  static String get scanClose => _t('关闭', 'Close');
  static String get scanIdleHint =>
      _t('点击"探测"开始匹配引擎', 'Tap "Probe" to match an engine');

  // Content / Browse
  static String get content => _t('内容', 'Content');
  static String get tapToView => _t('点击查看', 'Tap to view');
  static String get nsfw => _t('NSFW', 'NSFW');
  static String get noContent => _t('暂无内容', 'Nothing here yet');
  static String get poolEmpty => _t('该图集暂无内容', 'This pool is empty');

  // Hosts Page
  static String get hostsTitle => _t('Host 规则', 'Host rules');
  static String get addHost => _t('添加映射', 'Add mapping');
  static String get noHostMappings => _t('还没有 Host 规则', 'No host rules yet');
  static String get addMappingsHint =>
      _t('添加规则以通过自定义 IP 访问 Booru 站点', 'Add rules to reach booru sites via custom IPs');
  static String get addHostMapping => _t('添加 Host 规则', 'Add host rule');
  static String get domain => _t('域名', 'Domain');
  static String get domainHint => _t('例如 gelbooru.com', 'e.g. gelbooru.com');
  static String get ipAddress => _t('IP 地址', 'IP address');
  static String get ipHint => _t('例如 1.2.3.4', 'e.g. 1.2.3.4');
  static String get add => _t('添加', 'Add');
  static String get hostsEditorHint => _t('每行一条规则：IP 域名', 'One rule per line: IP domain');
  static String get hostsEditorExample => _t(
      '# 注释行以 # 开头\n# 格式: IP 域名\n1.2.3.4 gelbooru.com\n5.6.7.8 danbooru.donmai.us',
      '# Lines starting with # are comments\n# Format: IP domain\n1.2.3.4 gelbooru.com\n5.6.7.8 danbooru.donmai.us');
  static String get hostsParsed => _t('解析到 ', 'Parsed ');
  static String get hostsRules => _t(' 条规则', ' rules');
  static String get importHostsFile => _t('导入 Hosts 文件', 'Import hosts file');
  static String get importSuccess => _t('导入成功', 'Imported');
  static String get save => _t('保存', 'Save');
  static String get saved => _t('已保存', 'Saved');
  static String get hostsOnTip => _t('Hosts 已启用', 'Hosts enabled');
  static String get hostsOffTip => _t('Hosts 未启用', 'Hosts disabled');

  // Search page
  static String get noMatchingTags => _t('没有匹配的标签', 'No matching tags');
  static String get suggestionsFailed => _t('建议加载失败', 'Failed to load suggestions');
  static String get switchColumns => _t('切换列数', 'Cycle columns');
  static String get backToTop => _t('回到顶部', 'Back to top');
  static String get backAction => _t('返回', 'Back');

  // Errors
  static String get somethingWentWrong => _t('出错了', 'Something went wrong');
  static String get retry => _t('重试', 'Retry');

  // 加载更多
  static String get loadMoreFailed => _t('加载更多失败', 'Failed to load more');
  static String get retryLoadMore => _t('重试加载', 'Retry loading');
  static String get noServerSelected =>
      _t('尚未选择站点，请先在「服务器」中添加一个', 'No site selected yet. Add one in Servers first.');

  // 底层异常 → 用户提示（供 _friendlyError 使用）
  static String get errTimeout =>
      _t('连接超时，请检查网络或尝试使用 Hosts 功能', 'Connection timed out. Check your network or try the Hosts feature.');
  static String get errReceiveTimeout =>
      _t('服务器响应超时，请稍后重试', 'Server took too long to respond. Try again later.');
  static String get errRefused =>
      _t('连接被拒绝，请检查服务器地址是否正确', 'Connection refused. Check the server address.');
  static String get errDns =>
      _t('域名解析失败，请检查网络或服务器地址', 'DNS lookup failed. Check your network or the server address.');
  static String get errTls => _t('安全连接失败（证书校验未通过），请检查系统时间或网络环境',
      'Secure connection failed (certificate not verified). Check the system clock or network.');
  static String get err403 =>
      _t('访问被拒绝（403），可能需要登录或 API 密钥', 'Access denied (403). You may need to sign in or set an API key.');
  static String get err404 =>
      _t('资源不存在（404），服务器地址可能已变更', 'Not found (404). The server address may have changed.');
  static String get err429 =>
      _t('请求过于频繁（429），请稍后再试', 'Too many requests (429). Try again later.');
  static String get err5xx =>
      _t('服务器内部错误（5xx），请稍后再试', 'Server error (5xx). Try again later.');
  static String get errNetwork =>
      _t('网络异常，请检查网络连接', 'Network error. Check your connection.');
  static String get errBadPayload => _t('服务器返回数据异常，可能不是有效的 Booru 站点',
      'Unexpected response. This may not be a valid booru site.');

  // Sort options - labels for display
  static String sortLabel(String key) {
    switch (key) {
      case 'relevance':
        return sortRelevance;
      case 'score':
        return sortScore;
      case 'date':
        return sortDate;
      case 'rating':
        return sortRating;
      default:
        return key;
    }
  }

  /// 底层异常 → 面向用户的提示。
  ///
  /// 放在文案层而不是某个页面里：此前它是 `home_content` 的私有函数，
  /// 其他页面（探索/图集/图集详情）只能把 `e.toString()` 的英文栈丢给用户。
  /// 全应用一份映射，也保证同一个错误在任何页面说法一致。
  static String friendlyError(Object error) {
    final raw = error.toString();
    // 哨兵错误码（page_state 在「未选站点」时写入）在这里映射成文案，
    // 避免状态层硬编码语言。
    const noServerSentinel = 'noServerSelected';
    if (raw.contains(noServerSentinel)) {
      return noServerSelected;
    }
    if (raw.contains('connection timeout') ||
        raw.contains('Connection timeout') ||
        raw.contains('connectionTimeout')) {
      return errTimeout;
    }
    if (raw.contains('receiveTimeout') || raw.contains('Receive timeout')) {
      return errReceiveTimeout;
    }
    if (raw.contains('Connection refused')) {
      return errRefused;
    }
    if (raw.contains('Failed host lookup') ||
        raw.contains('No address associated with hostname')) {
      return errDns;
    }
    if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE')) {
      return errTls;
    }
    if (RegExp(r'status (code )?of 403').hasMatch(raw)) {
      return err403;
    }
    if (RegExp(r'status (code )?of 404').hasMatch(raw)) {
      return err404;
    }
    if (RegExp(r'status (code )?of 429').hasMatch(raw)) {
      return err429;
    }
    if (RegExp(r'status (code )?of 5\d\d').hasMatch(raw)) {
      return err5xx;
    }
    if (raw.contains('SocketException')) {
      return errNetwork;
    }
    if (raw.contains('XML') || raw.contains('parser') || raw.contains('json')) {
      return errBadPayload;
    }
    final lines = raw.split('\n');
    return lines.length > 2 ? '${lines[0]}\n${lines[1]}' : raw;
  }

  /// 中文优先、英文随语言切换返回。
  static String _t(String zh, String en) => isEn ? en : zh;
}
