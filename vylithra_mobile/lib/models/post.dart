class Post {
  final String id;
  final String content;
  final String? image;
  final String? videoUrl;
  final String authorName;
  final String authorProfilePicture;
  final String userId;
  final bool isAnonymous;
  List<String> likes;
  List<dynamic> comments;

  Post({
    required this.id,
    required this.content,
    this.image,
    this.videoUrl,
    required this.authorName,
    required this.authorProfilePicture,
    required this.userId,
    this.isAnonymous = false,
    this.likes = const [],
    this.comments = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      image: json['image'],
      videoUrl: json['videoUrl'] ?? json['attachment'],
      authorName: json['isAnonymous'] == true ? 'Anonymous' : (json['user']?['username'] ?? json['username'] ?? 'Unknown'),
      authorProfilePicture: json['isAnonymous'] == true ? '' : (json['user']?['profilePicture'] ?? ''),
      userId: json['isAnonymous'] == true ? '' : (json['user'] is Map ? (json['user']['_id'] ?? '') : (json['user'] ?? '')),
      isAnonymous: json['isAnonymous'] ?? false,
      likes: (json['likes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      comments: json['comments'] ?? [],
    );
  }
}
