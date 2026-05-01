class Post {
  final String id;
  final String content;
  final String? image;
  final String authorName;

  Post({
    required this.id,
    required this.content,
    this.image,
    required this.authorName,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      image: json['image'],
      authorName: json['user']?['username'] ?? json['username'] ?? 'Unknown',
    );
  }
}
