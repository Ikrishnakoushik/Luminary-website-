class Post {
  final String id;
  final String content;
  final String? image;
  final String? videoUrl;
  final String authorName;
  final String authorProfilePicture;
  final String userId;

  Post({
    required this.id,
    required this.content,
    this.image,
    this.videoUrl,
    required this.authorName,
    required this.authorProfilePicture,
    required this.userId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      image: json['image'],
      videoUrl: json['videoUrl'] ?? json['attachment'],
      authorName: json['user']?['username'] ?? json['username'] ?? 'Unknown',
      authorProfilePicture: json['user']?['profilePicture'] ?? '',
      userId: json['user'] is Map ? (json['user']['_id'] ?? '') : (json['user'] ?? ''),
    );
  }
}
