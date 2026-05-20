const fs = require('fs');

let code = fs.readFileSync('vylithra_mobile/lib/widgets/post_card.dart', 'utf8');

if (!code.includes("import '../models/story.dart';")) {
    code = code.replace("import '../models/post.dart';", "import '../models/post.dart';\nimport '../models/story.dart';\nimport '../screens/story_viewer_screen.dart';\nimport '../providers/auth_provider.dart';\nimport 'package:provider/provider.dart';\nimport 'package:cached_network_image/cached_network_image.dart';");
}

if (!code.includes("final List<StoryGroup>? storyGroups;")) {
    code = code.replace("final Post post;", "final Post post;\n  final List<StoryGroup>? storyGroups;");
    code = code.replace("const PostCard({super.key, required this.post});", "const PostCard({super.key, required this.post, this.storyGroups});");
}

const replacementAvatar = `
                    Builder(builder: (context) {
                      final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?['id'];
                      final authorId = widget.post.user is Map ? widget.post.user['_id'] : widget.post.user;
                      
                      StoryGroup? group;
                      if (widget.storyGroups != null && authorId != null) {
                        try {
                           group = widget.storyGroups!.firstWhere((g) => g.userId == authorId);
                        } catch(e) {}
                      }
                      
                      final bool hasActiveStory = group != null && !group.stories.every((s) => s.viewers.contains(currentUserId));
                      
                      Widget avatarWidget = CircleAvatar(
                        radius: 20,
                        backgroundImage: widget.post.authorProfilePicture.isNotEmpty 
                          ? CachedNetworkImageProvider(widget.post.authorProfilePicture)
                          : null,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: widget.post.authorProfilePicture.isEmpty 
                          ? Text(widget.post.authorName.isNotEmpty ? widget.post.authorName[0].toUpperCase() : 'U')
                          : null,
                      );
                      
                      if (hasActiveStory) {
                         avatarWidget = Container(
                           padding: const EdgeInsets.all(2),
                           decoration: const BoxDecoration(
                             shape: BoxShape.circle,
                             gradient: LinearGradient(
                               colors: [Colors.purple, Colors.orange],
                               begin: Alignment.topRight,
                               end: Alignment.bottomLeft,
                             ),
                           ),
                           child: Container(
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                             ),
                             child: avatarWidget,
                           ),
                         );
                      }
                      
                      return GestureDetector(
                        onTap: () {
                          if (group != null) {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(
                               stories: group!.stories,
                               userName: group.userName,
                               userProfilePicture: group.userProfilePicture,
                               onComplete: () { if(mounted) setState((){}); },
                             )));
                          } else {
                             // Go to profile
                             // Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)));
                          }
                        },
                        child: avatarWidget,
                      );
                    }),
`;

// Replace CircleAvatar block
if (!code.includes("hasActiveStory = group !=")) {
    code = code.replace(/CircleAvatar\([\s\S]*?child: Icon\(Icons\.person, color: Theme\.of\(context\)\.colorScheme\.primary\),[\s\S]*?\),/g, replacementAvatar);
    fs.writeFileSync('vylithra_mobile/lib/widgets/post_card.dart', code);
    console.log("PostCard updated successfully.");
}
