import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// Zeigt ein per URL geladenes SVG-Logo robust an.
///
/// Hintergrund: `SvgPicture.network` parst die SVG-Daten in einem
/// Hintergrund-Isolate (`compute`). Liefert die URL kein gültiges SVG
/// zurück (z.B. eine 404-Antwort vom CDN, weil ein Logo-Slug nicht (mehr)
/// existiert), wirft der Parser eine "Bad state: Invalid SVG data"
/// Exception. Diese wird in der aktuell verwendeten flutter_svg/
/// vector_graphics-Version NICHT zuverlässig über `errorBuilder`
/// abgefangen, sondern taucht als "Unhandled Exception" im Log auf.
///
/// Um das zu vermeiden, laden und validieren wir die Bytes hier selbst
/// (einfache Prüfung auf ein "<svg"-Tag in der Antwort) und übergeben sie
/// nur dann an `SvgPicture.memory`. Ist die Antwort kein SVG oder schlägt
/// der Download fehl, wird direkt ein Fallback (erster Buchstabe des
/// Namens) angezeigt - ohne den fehleranfälligen Parser überhaupt erst
/// aufzurufen.
class SafeSvgLogo extends StatefulWidget {
  final String url;
  final Color color;
  final String fallbackLetter;

  const SafeSvgLogo({
    super.key,
    required this.url,
    required this.color,
    required this.fallbackLetter,
  });

  @override
  State<SafeSvgLogo> createState() => _SafeSvgLogoState();
}

class _SafeSvgLogoState extends State<SafeSvgLogo> {
  // Kleiner Prozess-Cache: verhindert wiederholte Downloads/Validierungen
  // desselben Logos (z.B. beim erneuten Öffnen des Logo-Pickers).
  static final Map<String, Uint8List?> _cache = {};

  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAndValidate(widget.url);
  }

  @override
  void didUpdateWidget(covariant SafeSvgLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = _loadAndValidate(widget.url);
    }
  }

  static Future<Uint8List?> _loadAndValidate(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url];
    }
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && _looksLikeSvg(response.bodyBytes)) {
        _cache[url] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SafeSvgLogo] Konnte Logo nicht laden ($url): $e');
    }
    _cache[url] = null;
    return null;
  }

  /// Grobe Prüfung, ob die Antwort tatsächlich SVG-Markup enthält, statt
  /// z.B. einer 404-HTML-Seite oder einem JSON-Fehlerobjekt.
  static bool _looksLikeSvg(Uint8List bytes) {
    final headLength = bytes.length < 500 ? bytes.length : 500;
    final head = String.fromCharCodes(bytes.sublist(0, headLength)).toLowerCase();
    return head.contains('<svg');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          return _fallback();
        }

        return SvgPicture.memory(
          bytes,
          colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
          errorBuilder: (context, error, stackTrace) => _fallback(),
        );
      },
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        widget.fallbackLetter,
        style: TextStyle(color: widget.color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
