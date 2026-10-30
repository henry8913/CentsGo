import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external URL in the platform browser/app, with a snackbar when the
/// platform refuses (missing handler, sandbox, no browser).
Future<bool> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire $url')),
      );
    }
    return ok;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il collegamento: $e')),
      );
    }
    return false;
  }
}
