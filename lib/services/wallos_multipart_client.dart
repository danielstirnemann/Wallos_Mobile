import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Sendet POST-Requests als multipart/form-data, ohne automatisch
/// Redirects zu folgen.
///
/// Wird für den Logo-Upload benötigt (Wallos erwartet Dateien unter dem
/// Feldnamen "logo" als `$_FILES['logo']`). Manche selbst gehosteten
/// Wallos-Instanzen (z.B. hinter DuckDNS) antworten mit einem 301-Redirect
/// von http auf https - folgt man dem automatisch, wird aus dem POST oft
/// ein GET und die hochgeladene Datei geht verloren.
class WallosMultipartClient {
  static Future<http.Response> postWithoutRedirect(
    Uri url, {
    Map<String, String>? fields,
    String? fileFieldName,
    Uint8List? fileBytes,
    String? fileName,
    String fileContentType = 'image/png',
  }) async {
    final boundary = '----WallosMobile${DateTime.now().millisecondsSinceEpoch}';
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 30);

    try {
      final request = await httpClient.postUrl(url);
      request.headers.set(
        'Content-Type',
        'multipart/form-data; boundary=$boundary',
      );

      final body = BytesBuilder();

      fields?.forEach((key, value) {
        body.add(utf8.encode('--$boundary\r\n'));
        body.add(
          utf8.encode('Content-Disposition: form-data; name="$key"\r\n\r\n'),
        );
        body.add(utf8.encode('$value\r\n'));
      });

      if (fileBytes != null && fileFieldName != null) {
        final safeFileName = fileName ?? 'logo.png';
        body.add(utf8.encode('--$boundary\r\n'));
        body.add(
          utf8.encode(
            'Content-Disposition: form-data; name="$fileFieldName"; filename="$safeFileName"\r\n',
          ),
        );
        body.add(utf8.encode('Content-Type: $fileContentType\r\n\r\n'));
        body.add(fileBytes);
        body.add(utf8.encode('\r\n'));
      }

      body.add(utf8.encode('--$boundary--\r\n'));

      final bodyBytes = body.toBytes();
      request.headers.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      return http.Response(responseBody, response.statusCode);
    } catch (e) {
      print('[ERROR] WallosMultipartClient.postWithoutRedirect failed: $e');
      return http.Response('Netzwerkfehler: $e', 0);
    } finally {
      httpClient.close();
    }
  }
}
