import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _hideProfileOnPosts = false;
  bool _isPrivate = false;

  final Color bgColor = const Color(0xFFF8F6EB);
  final Color darkTextColor = const Color(0xFF3E2723);

  @override
  void initState() {
    super.initState();
    _fetchPrivacySettings();
  }

  Future<void> _fetchPrivacySettings() async {
    try {
      final res = await _apiService.get('/api/users/privacy');
      if (mounted) {
        setState(() {
          _hideProfileOnPosts = res['hideProfileOnPosts'] ?? false;
          _isPrivate = res['isPrivate'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load settings: $e')));
      }
    }
  }

  Future<void> _toggleHideProfile(bool value) async {
    setState(() => _hideProfileOnPosts = value);
    try {
      await _apiService.put('/api/users/privacy', {
        'hideProfileOnPosts': value,
        'isPrivate': _isPrivate,
      });
    } catch (e) {
      setState(() => _hideProfileOnPosts = !value); // Revert
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _toggleIsPrivate(bool value) async {
    setState(() => _isPrivate = value);
    try {
      await _apiService.put('/api/users/privacy', {
        'hideProfileOnPosts': _hideProfileOnPosts,
        'isPrivate': value,
      });
    } catch (e) {
      setState(() => _isPrivate = !value); // Revert
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : bgColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : darkTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: isDark ? Colors.white : darkTextColor,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Text(
                    'Interactions'.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.grey[400]
                          : const Color(0xFF5D4037).withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Hide Profile on Posts',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : darkTextColor,
                    ),
                  ),
                  subtitle: Text(
                    'If enabled, your posts and reels will be published anonymously by default.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white54
                          : darkTextColor.withValues(alpha: 0.6),
                    ),
                  ),
                  value: _hideProfileOnPosts,
                  activeThumbColor: Colors.blueAccent,
                  onChanged: _toggleHideProfile,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Private Account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : darkTextColor,
                    ),
                  ),
                  subtitle: Text(
                    'Only approved followers can see your posts and profile.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white54
                          : darkTextColor.withValues(alpha: 0.6),
                    ),
                  ),
                  value: _isPrivate,
                  activeThumbColor: Colors.blueAccent,
                  onChanged: _toggleIsPrivate,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                const Divider(height: 30, thickness: 1, color: Colors.black12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.block,
                    color: isDark ? Colors.white70 : darkTextColor,
                  ),
                  title: Text(
                    'Blocked Accounts',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : darkTextColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Blocked accounts coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
