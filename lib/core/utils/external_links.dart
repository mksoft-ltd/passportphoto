import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the browser. Returns false when the platform refused, so the
/// caller can say so instead of leaving a dead-looking button.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('PassportPhoto: could not open $url: $e');
    return false;
  }
}
