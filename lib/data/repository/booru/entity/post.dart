class BooruPost {
  const BooruPost({
    required this.id,
    required this.serverId,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.tags,
    required this.aspectRatio,
    required this.width,
    required this.height,
    required this.rating,
    required this.score,
    this.source,
    this.postUrl,
    this.uploader,
    this.tagGeneral = const [],
    this.tagArtist = const [],
    this.tagCharacter = const [],
    this.tagCopyright = const [],
    this.tagMeta = const [],
    this.isVideo = false,
  });

  factory BooruPost.fromJson(Map<String, dynamic> json) => BooruPost(
        id: json['id']?.toString() ?? '',
        serverId: json['serverId']?.toString() ?? '',
        thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
        sampleUrl: json['sampleUrl']?.toString() ?? '',
        originalUrl: json['originalUrl']?.toString() ?? '',
        tags: _tagList(json['tags']),
        aspectRatio: json['aspectRatio'] is num
            ? (json['aspectRatio'] as num).toDouble()
            : 1.0,
        width: json['width'] is int ? json['width'] as int : 0,
        height: json['height'] is int ? json['height'] as int : 0,
        rating: json['rating']?.toString() ?? 'q',
        score: json['score'] is int ? json['score'] as int : 0,
        source: json['source']?.toString(),
        postUrl: json['postUrl']?.toString(),
        uploader: json['uploader']?.toString(),
        tagGeneral: _tagList(json['tagGeneral']),
        tagArtist: _tagList(json['tagArtist']),
        tagCharacter: _tagList(json['tagCharacter']),
        tagCopyright: _tagList(json['tagCopyright']),
        tagMeta: _tagList(json['tagMeta']),
        // 老数据没有这个字段：默认 false，读回来仍按 URL 判定兼容
        isVideo: json['isVideo'] == true,
      );

  static List<String> _tagList(Object? v) =>
      v is List ? List<String>.from(v) : [];

  final String id;
  final String serverId;
  final String thumbnailUrl;
  final String sampleUrl;
  final String originalUrl;
  final List<String> tags;
  final double aspectRatio;
  final int width;
  final int height;
  final String rating;
  final int score;
  final String? source;
  final String? postUrl;
  final String? uploader;
  final List<String> tagGeneral;
  final List<String> tagArtist;
  final List<String> tagCharacter;
  final List<String> tagCopyright;
  final List<String> tagMeta;

  /// 视频帖标记。
  ///
  /// 视频站的列表页**只给缩略图**，帖子里没有任何 mp4/HLS 地址（播放地址要
  /// 打开详情页才解析得出来）。因此"这是不是视频"必须由解析器显式告知，
  /// 不能靠 URL 后缀去猜——猜的结果是视频帖被当成图片帖渲染。
  final bool isVideo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'thumbnailUrl': thumbnailUrl,
        'sampleUrl': sampleUrl,
        'originalUrl': originalUrl,
        'tags': tags,
        'aspectRatio': aspectRatio,
        'width': width,
        'height': height,
        'rating': rating,
        'score': score,
        'source': source,
        'postUrl': postUrl,
        'uploader': uploader,
        'tagGeneral': tagGeneral,
        'tagArtist': tagArtist,
        'tagCharacter': tagCharacter,
        'tagCopyright': tagCopyright,
        'tagMeta': tagMeta,
        'isVideo': isVideo,
      };

  static const empty = BooruPost(
    id: '',
    serverId: '',
    thumbnailUrl: '',
    sampleUrl: '',
    originalUrl: '',
    tags: [],
    aspectRatio: 1.0,
    width: 0,
    height: 0,
    rating: 'q',
    score: 0,
  );
}
