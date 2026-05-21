import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalPoliciesScreen extends StatelessWidget {
  const LegalPoliciesScreen({super.key});

  Widget _buildLawSection(String title, String description, String acts, bool isDark, Color lightTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            acts,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : lightTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.black12, thickness: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F6EB);
    final darkTextColor = const Color(0xFF3E2723);
    final lightTextColor = const Color(0xFF5D4037);

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
          'Legal & Policies',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: isDark ? Colors.white : darkTextColor,
          ),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Community Guidelines & Laws',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : darkTextColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Vylithra strictly adheres to international and local laws. Any violation of these laws on our platform will result in account suspension and may be reported to law enforcement agencies.',
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white70 : lightTextColor,
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildLawSection(
            'Hate Speech & Discrimination',
            'Posting content that promotes violence, hatred, or discrimination against groups based on race, religion, gender, or sexual orientation is strictly prohibited.',
            'IT Act Sec 66A / 153A IPC',
            isDark,
            lightTextColor,
          ),
          
          _buildLawSection(
            'Harassment or Bullying',
            'Threatening, stalking, or bullying other users. This includes sharing private information (doxxing) without consent.',
            'IT Act Sec 67 & IPC 509',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Obscene or Nudity',
            'Publishing or transmitting material that is lascivious or appeals to the prurient interest is illegal and will be removed.',
            'IT Act Sec 67, 67A',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Child Exploitation (CSAM)',
            'Publishing, transmitting, or browsing material depicting children in sexually explicit acts is a severe criminal offense.',
            'POCSO Act / IT Act Sec 67B',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Privacy Violation',
            'Capturing, publishing, or transmitting the image of a private area of any person without their consent.',
            'IT Act Sec 66E',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Identity Theft',
            'Fraudulently or dishonestly making use of the electronic signature, password, or any other unique identification feature of any other person.',
            'IT Act Sec 66C',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Defamation',
            'Making or publishing any imputation concerning any person intending to harm, or knowing or having reason to believe that such imputation will harm, the reputation of such person.',
            'IPC Sec 499 & 500',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Fake News & Misinformation',
            'Publishing or circulating false statements, rumors, or alarming news with intent to cause fear, panic, or incite violence among the public.',
            'IPC Sec 505 / IT Rules',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Cyber Extortion & Blackmail',
            'Intentionally putting any person in fear of injury or defamation in order to dishonestly induce them to deliver property or money.',
            'IPC Sec 384 & 503',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Voyeurism',
            'Watching, capturing, or disseminating images of a person engaging in a private act in circumstances where they would usually have an expectation of privacy.',
            'IPC Sec 354C',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Cyber Stalking',
            'Monitoring the use by a person of the internet, email, or any other form of electronic communication without their consent to foster personal interaction.',
            'IPC Sec 354D',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Copyright Infringement',
            'Sharing copyrighted material (videos, images, text, code) without explicit permission or fair use rights.',
            'DMCA Title 17 / Copyright Act, 1957',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Terrorism or Illegal Acts',
            'Content that threatens the unity, integrity, defense, security, or sovereignty of a nation, or incites terrorism.',
            'IT Act Sec 66F',
            isDark,
            lightTextColor,
          ),

          _buildLawSection(
            'Spam, Phishing or Scam',
            'Cheating by personation using a computer resource, distributing malware, or mass-spamming users with fraudulent links.',
            'IT Act Sec 66D',
            isDark,
            lightTextColor,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
