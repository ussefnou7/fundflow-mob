import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Opens a public web page (privacy policy, support) in an in-app browser.
Future<void> _open(BuildContext context, String url, String failure) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.inAppBrowserView,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
  }
}

String get _platform => Platform.isIOS ? 'ios' : 'android';

/// The privacy policy and support links the stores require inside the app.
/// Hidden in builds without `WEB_BASE_URL`.
class PublicLinks extends StatelessWidget {
  const PublicLinks({
    super.key,
    this.color,
    this.baseUrl = AppConfig.webBaseUrl,
  });

  final Color? color;

  /// The web host serving `/privacy` and `/support`.
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    if (baseUrl.isEmpty) return const SizedBox.shrink();
    final style = TextButton.styleFrom(
      foregroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // Cairo, as everywhere: a bare TextStyle here would drop the theme font.
      textStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton.icon(
          key: const ValueKey('privacy-policy-link'),
          style: style,
          onPressed: () => _open(
            context,
            '$baseUrl/privacy',
            'تعذر فتح سياسة الخصوصية',
          ),
          icon: const Icon(LucideIcons.shieldCheck, size: 16),
          label: const Text('سياسة الخصوصية'),
        ),
        TextButton.icon(
          key: const ValueKey('support-link'),
          style: style,
          onPressed: () => _open(
            context,
            '$baseUrl/support?source=$_platform',
            'تعذر فتح صفحة الدعم الفني',
          ),
          icon: const Icon(LucideIcons.lifeBuoy, size: 16),
          label: const Text('الدعم الفني'),
        ),
      ],
    );
  }
}
