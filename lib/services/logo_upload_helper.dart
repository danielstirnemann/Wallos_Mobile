import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import '../utils/hex_color.dart';

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
  /// [hexColor] ist die Marken-Farbe (z.B. "#E50914") des gewählten
  /// Simple-Icons-Logos (siehe [Subscription.logoHex]). Simple-Icons-SVGs
  /// enthalten selbst KEINE Farbe (nur einen einfarbigen Pfad, der ohne
  /// weitere Einfärbung schwarz gerendert wird) - ohne [hexColor] würde das
  /// hochgeladene PNG daher schwarz/monochrom statt in der Markenfarbe
  /// erscheinen.
  static Future<PreparedLogo?> prepare(String? logoUrl, {String? hexColor}) async {
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

      final pngBytes = isSvg
          ? await _rasterizeSvg(bytes, color: parseHexColor(hexColor))
          : bytes;
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

  static Future<Uint8List?> _rasterizeSvg(Uint8List svgBytes, {int size = 256, ui.Color? color}) async {
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

      // Färbt das gesamte SVG einheitlich in der Marken-Farbe ein - analog
      // zu SvgPicture's `colorFilter`-Property, die beim reinen Anzeigen
      // (siehe SafeSvgLogo) verwendet wird. Ohne dies würde die PNG-Datei,
      // die tatsächlich an Wallos hochgeladen wird, in der SVG-eigenen
      // Standard-Füllfarbe (i.d.R. Schwarz) gerendert.
      final needsColorLayer = color != null;
      if (needsColorLayer) {
        final layerPaint = ui.Paint()
          ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);
        canvas.saveLayer(
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          layerPaint,
        );
      }

      canvas.scale(scale, scale);
      canvas.drawPicture(picture);

      if (needsColorLayer) {
        canvas.restore();
      }

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
