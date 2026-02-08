import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A banner that prompts mobile web users to download the native app.
/// Only shows on web platform when accessed from a mobile browser.
class AppDownloadBanner extends StatefulWidget {
  const AppDownloadBanner({super.key, required this.child});

  final Widget child;

  @override
  State<AppDownloadBanner> createState() => _AppDownloadBannerState();
}

class _AppDownloadBannerState extends State<AppDownloadBanner> {
  static const _dismissedKey = 'app_download_banner_dismissed';
  bool _showBanner = false;
  bool _isLoading = true;

  // TODO: Update these with your actual store URLs when published
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.example.vibeu';
  static const String appStoreUrl = 'https://apps.apple.com/app/vibeu/id123456789';

  @override
  void initState() {
    super.initState();
    _checkIfShouldShowBanner();
  }

  Future<void> _checkIfShouldShowBanner() async {
    // Only show on web
    if (!kIsWeb) {
      setState(() {
        _showBanner = false;
        _isLoading = false;
      });
      return;
    }

    // Check if user previously dismissed the banner
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_dismissedKey) ?? false;

    setState(() {
      _showBanner = !dismissed && _isMobileBrowser();
      _isLoading = false;
    });
  }

  bool _isMobileBrowser() {
    // On web, check if it's a mobile browser using the platform info
    // This is a simple heuristic based on screen width
    if (!kIsWeb) return false;
    
    // We'll use a post-frame callback to check the screen width
    // For now, return true and let the build method handle the check
    return true;
  }

  Future<void> _dismissBanner({bool permanent = false}) async {
    if (permanent) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissedKey, true);
    }
    setState(() => _showBanner = false);
  }

  void _openStore(BuildContext context) {
    final platform = Theme.of(context).platform;
    final url = platform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;
    
    // Show a dialog since the app isn't published yet
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The mobile app will be available soon on:'),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.android, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Google Play Store'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.apple, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text('Apple App Store'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Store URL: $url',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    
    // TODO: When app is published, uncomment this to open the store:
    // launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Don't show while loading or if banner is hidden
    if (_isLoading || !_showBanner) {
      return widget.child;
    }

    // Check screen width to determine if it's likely a mobile device
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileWidth = screenWidth < 600;

    if (!isMobileWidth) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Download Banner
        Material(
          color: isDark 
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.primary,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // App Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '💕',
                        style: TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'VibeU',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark 
                                ? theme.colorScheme.onPrimaryContainer
                                : Colors.white,
                          ),
                        ),
                        Text(
                          'Get the app for a better experience',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark 
                                ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Download Button
                  FilledButton(
                    onPressed: () => _openStore(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark 
                          ? theme.colorScheme.primary
                          : Colors.white,
                      foregroundColor: isDark
                          ? Colors.white
                          : theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('GET'),
                  ),
                  const SizedBox(width: 8),
                  // Close Button
                  IconButton(
                    onPressed: () => _dismissBanner(permanent: true),
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: isDark 
                          ? theme.colorScheme.onPrimaryContainer
                          : Colors.white,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Main Content
        Expanded(child: widget.child),
      ],
    );
  }
}
