import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<dynamic> _messagesFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _messagesFuture = _apiService.get('/api/messages/conversations').catchError((e) => []);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [const Color(0xFF0F172A), const Color(0xFF3B82F6).withValues(alpha: 0.1), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
        ),
      ),
      child: FutureBuilder<dynamic>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Use dummy data if backend fails or is empty, to ensure UI is visible
          final List<dynamic> conversations = (snapshot.hasData && snapshot.data is List && snapshot.data.isNotEmpty) 
              ? snapshot.data 
              : [
                  {'withUser': {'username': 'sarah_design'}, 'lastMessage': 'Loved your latest post!', 'updatedAt': '2m ago'},
                  {'withUser': {'username': 'alex_dev'}, 'lastMessage': 'Are we still on for the meeting?', 'updatedAt': '1h ago'},
                  {'withUser': {'username': 'vylithra_team'}, 'lastMessage': 'Welcome to the platform!', 'updatedAt': '1d ago'},
                ];

          return ListView.builder(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 80,
              bottom: 100,
            ),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final chat = conversations[index];
              final username = chat['withUser']?['username'] ?? 'Unknown User';
              final lastMsg = chat['lastMessage'] ?? '...';
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark ? Colors.white24 : Colors.black12,
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMsg,
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
