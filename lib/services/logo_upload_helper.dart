import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;

/// Ein heruntergeladenes und ggf. konvertiertes Logo, bereit für den Upload
/// als Datei an die Wallos-API.
class PreparedLogo {
  final Uint8List bytes;
  final String filename;

  PreparedLogo({required this.bytes, required this.filename});
}

/// Lädt ein Logo (z.B. eine Simple-Icons SVG-URL) herunter und wandelt es
/// bei Bedarf in ein PNG um.
///
/// Wallos speichert Logos serverseitig über PHP's GD-Bibliothek
/// (`imagecreatefromstring`), welche SVG NICHT dekodieren kann. Ein SVG
/// direkt hochzuladen würde serverseitig stillschweigend fehlschlagen.
/// Deshalb wird SVG hier lokal (mit Flutters eigenem Vector-Graphics-
/// Renderer) zu einem transparenten PNG rasterisiert, bevor es hochgeladen
/// wird. Das funktioniert auch, wenn der selbst gehostete Wallos-Server
/// keinen Zugriff auf das Internet hat, um die Original-URL selbst
/// abzurufen.
class LogoUploadHelper {
  static Future<PreparedLogo?> prepare(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse(logoUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('[LogoUploadHelper] Download fehlgeschlagen: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      final isSvg = logoUrl.toLowerCase().contains('.svg') || _looksLikeSvg(bytes);

      final pngBytes = isSvg ? await _rasterizeSvg(bytes) : bytes;
      if (pngBytes == null) {
        return null;
      }

      return PreparedLogo(bytes: pngBytes, filename: _filenameFor(logoUrl));
    } catch (e) {
      print('[LogoUploadHelper] Fehler beim Vorbereiten des Logos: $e');
      return null;
    }
  }

  static bool _looksLikeSvg(Uint8List bytes) {
    final headLength = bytes.length < 256 ? bytes.length : 256;
    final head = String.fromCharCodes(bytes.sublist(0, headLength)).toLowerCase();
    return head.contains('<svg');
  }

  static String _filenameFor(String url) {
    final uri = Uri.tryParse(url);
    var base = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : 'logo';
    base = base.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    if (base.isEmpty) base = 'logo';
    return '$base.png';
  }

  static Future<Uint8List?> _rasterizeSvg(Uint8List svgBytes, {int size = 256}) async {
    ui.Picture? picture;
    ui.Image? image;
    try {
      final pictureInfo = await vg.loadPicture(SvgBytesLoader(svgBytes), null);
      picture = pictureInfo.picture;

      final srcSize = pictureInfo.size;
      final maxDim = srcSize.width > srcSize.height ? srcSize.width : srcSize.height;
      final scale = maxDim > 0 ? size / maxDim : 1.0;

      final width = (srcSize.width * scale).ceil().clamp(1, 1024);
      final height = (srcSize.height * scale).ceil().clamp(1, 1024);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(scale, scale);
      canvas.drawPicture(picture);
      final scaledPicture = recorder.endRecording();

      image = await scaledPicture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      scaledPicture.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('[LogoUploadHelper] SVG-Rasterisierung fehlgeschlagen: $e');
      return null;
    } finally {
      picture?.dispose();
      image?.dispose();
    }
  }
}
