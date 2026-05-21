import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'privacy_settings_screen.dart';
import 'saved_posts_screen.dart';
import 'notifications_settings_screen.dart';
import 'professional_license_screen.dart';
import 'legal_policies_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Vintage theme colors matching profile_screen.dart
  final Color bgColor = const Color(0xFFF8F6EB);
  final Color darkTextColor = const Color(0xFF3E2723);
  final Color lightTextColor = const Color(0xFF5D4037);

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : lightTextColor.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDark = false,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: iconColor ?? (isDark ? Colors.white70 : darkTextColor),
        size: 26,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor ?? (isDark ? Colors.white : darkTextColor),
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white30 : Colors.black26,
      ),
      onTap: onTap,
    );
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
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : darkTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: isDark ? Colors.white : darkTextColor,
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          
          // Account Section
          _buildSectionHeader('Account', isDark),
          _buildListTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit Profile coming soon!')),
              );
            },
          ),
          _buildListTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.bookmark_border,
            title: 'Saved',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedPostsScreen()),
              );
            },
          ),

          const Divider(height: 30, thickness: 1, color: Colors.black12),

          // App Settings Section
          _buildSectionHeader('App Settings', isDark),
          _buildListTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsSettingsScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            isDark: isDark,
            onTap: () {
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.toggleTheme(!themeProvider.isDarkMode);
            },
          ),

          const Divider(height: 30, thickness: 1, color: Colors.black12),

          // About Section
          _buildSectionHeader('About', isDark),
          _buildListTile(
            icon: Icons.help_outline,
            title: 'Help',
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help Center coming soon!')),
              );
            },
          ),
          _buildListTile(
            icon: Icons.info_outline,
            title: 'About Vylithra',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfessionalLicenseScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.gavel_outlined,
            title: 'Legal & Policies',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LegalPoliciesScreen()),
              );
            },
          ),

          const SizedBox(height: 20),

          // Log Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextButton(
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                Navigator.pop(context); // Pop Settings
                await auth.logout();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                'Log Out',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
