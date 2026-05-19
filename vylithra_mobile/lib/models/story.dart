class Story {
  final String id;
  final String userId;
  final String userName;
  final String userProfilePicture;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final List<String> viewers;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfilePicture,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.viewers,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['_id'] ?? '',
      userId: json['user'] is Map ? json['user']['_id'] : json['user'],
      userName: json['user'] is Map ? (json['user']['name'] ?? json['user']['username'] ?? 'User') : 'User',
      userProfilePicture: json['user'] is Map ? (json['user']['profilePicture'] ?? '') : '',
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'image',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      viewers: List<String>.from(json['viewers'] ?? []),
    );
  }
}

class StoryGroup {
  final String userId;
  final String userName;
  final String userProfilePicture;
  final List<Story> stories;
  final DateTime lastUpdated;

  StoryGroup({
    required this.userId,
    required this.userName,
    required this.userProfilePicture,
    required this.stories,
    required this.lastUpdated,
  });

  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    var storyList = json['stories'] as List? ?? [];
    List<Story> parsedStories = storyList.map((s) => Story.fromJson(s)).toList();

    return StoryGroup(
      userId: json['user']['_id'] ?? '',
      userName: json['user']['name'] ?? json['user']['username'] ?? 'User',
      userProfilePicture: json['user']['profilePicture'] ?? '',
      stories: parsedStories,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : DateTime.now(),
    );
  }
}
