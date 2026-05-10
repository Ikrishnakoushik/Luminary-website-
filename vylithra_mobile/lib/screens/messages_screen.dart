import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _conversations = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchConversations() async {
    try {
      final data = await _apiService.get('/api/messages/conversations');
      if (mounted) {
        setState(() {
          _conversations = data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _searchUsers(query);
      } else {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearching = true;
    });
    try {
      final data = await _apiService.get('/api/search?q=$query');
      if (mounted) {
        setState(() {
          _searchResults = data['users'] ?? [];
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void _navigateToChat(String userId, String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(targetUserId: userId, targetUsername: username),
      ),
    ).then((_) => _fetchConversations()); // Refresh conversation list when coming back
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
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
      child: Column(
        children: [
          // Custom Header with Search Bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search users to message...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black54),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // FIXED PADDING
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading && !_isSearching
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _buildSearchResults(isDark)
                    : _buildConversationList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No users found', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isDark ? Colors.white24 : Colors.black12,
            backgroundImage: user['profilePicture'] != null && user['profilePicture'].isNotEmpty
                ? NetworkImage(user['profilePicture'])
                : null,
            child: user['profilePicture'] == null || user['profilePicture'].isEmpty
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          title: Text(user['displayName'] ?? user['username'] ?? 'User', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          subtitle: Text('@${user['username'] ?? 'unknown'}', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          onTap: () {
             final String uid = user['_id'] ?? '';
             final String uname = user['displayName'] ?? user['username'] ?? 'User';
             if (uid.isNotEmpty) {
               _navigateToChat(uid, uname);
             }
          },
        );
      },
    );
  }

  Widget _buildConversationList(bool isDark) {
    // If backend returns empty, show a message instead of dummy data
    if (_conversations.isEmpty) {
      return Center(
        child: Text('Search for a user to start a conversation.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final chat = _conversations[index];
        final user = chat['user'] ?? chat['withUser'] ?? {};
        final username = user['displayName'] ?? user['username'] ?? 'Unknown User';
        final lastMsg = chat['lastMessage'] ?? '...';
        final userId = user['_id'];
        
        return GestureDetector(
          onTap: () {
            if (userId != null) {
              _navigateToChat(userId, username);
            }
          },
          child: Container(
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
                        backgroundImage: user['profilePicture'] != null && user['profilePicture'].isNotEmpty
                            ? NetworkImage(user['profilePicture'])
                            : null,
                        child: user['profilePicture'] == null || user['profilePicture'].isEmpty
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
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
          ),
        );
      },
    );
  }
}
