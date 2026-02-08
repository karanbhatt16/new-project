import 'package:flutter/material.dart';

/// Terms and Conditions page for FindMyValentine.
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective Date: February 2026',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Platform Name: FindMyValentine',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to FindMyValentine. These Terms and Conditions ("Terms") govern your access to and use of our website, mobile application, and related services (collectively referred to as the "Platform"). By creating an account, accessing, or using our services, you agree to comply with and be legally bound by these Terms. If you do not agree with any part of these Terms, you must discontinue use of the Platform immediately.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _buildSection(
              theme,
              '1. Acceptance of Terms',
              'By registering on FindMyValentine, you confirm that you have read, understood, and accepted these Terms and agree to abide by all applicable laws and regulations. Your continued use of the Platform constitutes ongoing acceptance of any updates or modifications to these Terms. We reserve the right to update or revise these Terms at any time, and it is your responsibility to review them periodically.',
            ),
            _buildSection(
              theme,
              '2. Eligibility',
              'You must be at least 18 years of age or the legal age of majority in your jurisdiction to use our services. By creating an account, you represent and warrant that you meet these eligibility requirements and that all information provided during registration is accurate and truthful. Accounts found to belong to underage or misrepresenting users may be permanently suspended or deleted without notice.',
            ),
            _buildSection(
              theme,
              '3. Account Registration and Responsibility',
              'Users are required to create an account using valid personal details. You are solely responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. Any unauthorized access, misuse, or suspicious activity must be reported immediately. We are not liable for any loss or damage arising from failure to protect your account information.',
            ),
            _buildSection(
              theme,
              '4. User Conduct and Acceptable Behavior',
              'FindMyValentine is committed to maintaining a respectful and safe environment. Users agree not to engage in harassment, abusive language, hate speech, discrimination, impersonation, spamming, scamming, or any activity that may harm other users. Any behavior deemed inappropriate, harmful, or illegal may result in warnings, temporary suspension, or permanent termination of the account at our sole discretion.',
            ),
            _buildSection(
              theme,
              '5. Data Privacy and Encryption',
              'We value user privacy and implement strong security measures, including encryption and secure storage technologies, to protect user data from unauthorized access. All personal information, messages, and profile details are stored using industry-standard encryption protocols to safeguard confidentiality. While we strive to ensure maximum protection, no system is completely immune to risks, and users acknowledge that internet-based services may carry inherent vulnerabilities.',
            ),
            _buildSection(
              theme,
              '6. Conditional Access to User Data',
              'Although user data is encrypted and treated with strict confidentiality, FindMyValentine reserves the right to access, review, monitor, or disclose user information when reasonably necessary. This includes situations involving violations of our Terms, reports of misconduct, suspected illegal activity, harassment, fraud, or threats to user safety. In such cases, we may access relevant data to investigate, take corrective action, or cooperate with law enforcement authorities. We may also modify, restrict, or permanently delete user content or accounts found to be in violation of our policies to protect the integrity of the community.',
            ),
            _buildSection(
              theme,
              '7. Content Ownership and License',
              'Users retain ownership of the content they upload, including photos, text, and personal information. However, by posting content on the Platform, you grant FindMyValentine a non-exclusive, worldwide, royalty-free license to use, display, host, reproduce, and distribute such content solely for the purpose of operating and improving the service. Content that violates our guidelines may be removed without notice.',
            ),
            _buildSection(
              theme,
              '8. Prohibited Activities',
              'Users must not use the Platform for unlawful or unethical purposes. This includes but is not limited to identity theft, catfishing, financial scams, solicitation of money, spreading malware, automated bots, or scraping data. Any attempt to exploit or manipulate the system for unfair advantage may lead to immediate termination and possible legal action.',
            ),
            _buildSection(
              theme,
              '9. Reporting and Moderation',
              'We encourage users to report suspicious or inappropriate behavior. Our moderation team may review profiles, messages, and activities to ensure community safety. Decisions made by our moderators regarding warnings, suspensions, or bans are final and are intended to protect the broader user base.',
            ),
            _buildSection(
              theme,
              '10. Account Suspension and Termination',
              'FindMyValentine reserves the right to suspend, restrict, or permanently terminate any account at its sole discretion if the user violates these Terms, engages in harmful behavior, or poses a risk to the platform or other users. Upon termination, we may delete associated data and content from our servers, except where retention is legally required.',
            ),
            _buildSection(
              theme,
              '11. Safety Disclaimer',
              'While we strive to create a safe and trustworthy environment, FindMyValentine does not conduct background checks on all users and cannot guarantee the accuracy of user-provided information. Users are encouraged to exercise caution when interacting with others and to prioritize personal safety when communicating or meeting offline.',
            ),
            _buildSection(
              theme,
              '12. Intellectual Property',
              'All trademarks, logos, software, design elements, and content on the Platform are the property of FindMyValentine or its licensors. Users may not copy, distribute, modify, or reproduce any part of the Platform without prior written permission.',
            ),
            _buildSection(
              theme,
              '13. Service Availability',
              'We aim to provide uninterrupted access to our services; however, we do not guarantee continuous availability. Maintenance, technical issues, or unforeseen circumstances may temporarily disrupt services. We are not liable for any inconvenience or loss resulting from downtime.',
            ),
            _buildSection(
              theme,
              '14. Limitation of Liability',
              'To the fullest extent permitted by law, FindMyValentine shall not be liable for any indirect, incidental, or consequential damages arising from your use of the Platform, including but not limited to emotional distress, financial loss, or disputes between users. Your use of the service is at your own risk.',
            ),
            _buildSection(
              theme,
              '15. Indemnification',
              'You agree to indemnify and hold harmless FindMyValentine, its affiliates, employees, and partners from any claims, damages, or expenses resulting from your misuse of the Platform, violation of these Terms, or infringement of the rights of others.',
            ),
            _buildSection(
              theme,
              '16. Modifications to the Service',
              'We reserve the right to modify, update, suspend, or discontinue any part of the Platform at any time without prior notice. Features may be added or removed to improve functionality, security, or compliance with legal requirements.',
            ),
            _buildSection(
              theme,
              '17. Governing Law',
              'These Terms shall be governed by and interpreted in accordance with the laws of the applicable jurisdiction. Any disputes arising from these Terms shall be subject to the exclusive jurisdiction of the competent courts.',
            ),
            _buildSection(
              theme,
              '18. Contact Information',
              'For any questions, concerns, or reports regarding these Terms or your account, please contact us at:\n\nEmail: support@findmyvalentine.com\nWebsite: www.findmyvalentine.com',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
