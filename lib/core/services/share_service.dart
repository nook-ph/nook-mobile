import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class ShareService {
  final http.Client httpClient;

  ShareService({required this.httpClient});

  Future<void> shareCafe({
    required String id,
    required String name,
    required String? imageUrl,
  }) async {
    // Keep the link on its own line for better auto-linking in share targets.
    final String deepLink = "ph.nook.app:///cafe/$id";
    final String message = "Check out $name on Nook!\n\n$deepLink";

    // Text-first approach: prioritize reliably sharing the deep link.
    try {
      await SharePlatform.instance.share(
        ShareParams(
          text: message,
          subject: name,
        ),
      );
    } catch (_) {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final response = await httpClient.get(Uri.parse(imageUrl));
          final directory = await getTemporaryDirectory();
          final imagePath = '${directory.path}/share_$id.png';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(response.bodyBytes);

          await SharePlatform.instance.share(
            ShareParams(
              files: [XFile(imagePath)],
              text: message,
              subject: name,
            ),
          );
          return;
        } catch (_) {
          // Fall through to last-resort text-only share.
        }
      }

      await SharePlatform.instance.share(
        ShareParams(text: message),
      );
    }
  }
}
