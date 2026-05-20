import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalLicenseScreen extends StatelessWidget {
  const ProfessionalLicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Licenses & Terms'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vylithra End User License Agreement',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Copyright © 2026 Vylithra Inc. All rights reserved.\n\n'
              'This software and associated documentation files (the "Software") are proprietary and confidential. '
              'Unauthorized copying, distribution, or modification of this Software, via any medium, is strictly prohibited.\n\n'
              '1. USE OF THE SOFTWARE\n'
              'By using the Vylithra application, you agree to adhere to our community guidelines and terms of service. '
              'Any abuse, manipulation, or unauthorized access to the application APIs will result in immediate termination of your account.\n\n'
              '2. PRIVACY & DATA\n'
              'Your data is processed securely and is subject to our Privacy Policy. We do not sell your personal data to third parties.\n\n'
              '3. INTELLECTUAL PROPERTY\n'
              'All trademarks, logos, and service marks displayed on the app are our property or the property of other third parties. '
              'You are not permitted to use these Marks without our prior written consent or the consent of such third party which may own the Marks.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
