import 'package:flutter/material.dart';
import '../services/logo_service.dart';
import 'safe_svg_logo.dart';

/// Logo-Picker Dialog - Auswahl von Logos wie im Wallos-Webinterface
class LogoPickerDialog extends StatefulWidget {
  final String? initialLogoSlug;
  final Function(LogoItem?) onLogoSelected;

  const LogoPickerDialog({
    super.key,
    this.initialLogoSlug,
    required this.onLogoSelected,
  });

  static Future<LogoItem?> show(
    BuildContext context, {
    String? initialLogoSlug,
  }) {
    return showDialog<LogoItem?>(
      context: context,
      builder: (context) => LogoPickerDialog(
        initialLogoSlug: initialLogoSlug,
        onLogoSelected: (logo) => Navigator.pop(context, logo),
      ),
    );
  }

  @override
  State<LogoPickerDialog> createState() => _LogoPickerDialogState();
}

class _LogoPickerDialogState extends State<LogoPickerDialog> {
  final _searchController = TextEditingController();
  final _logoService = LogoService();
  late Future<List<LogoItem>> _logosFuture;
  LogoItem? _selectedLogo;

  @override
  void initState() {
    super.initState();
    _logosFuture = _logoService.getAllLogos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        // Begrenzt die Dialoggröße (v.a. auf breiten/Desktop-Fenstern),
        // damit die Grid-Kacheln nicht unnötig groß werden.
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Logo wählen',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Netflix, Spotify, etc. eintippen...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1),
          // Logo Grid
          Expanded(
            child: FutureBuilder<List<LogoItem>>(
              future: _logosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Keine Logos gefunden'),
                  );
                }

                // Filter logos basierend auf Search
                final allLogos = snapshot.data!;
                final filteredLogos = _searchController.text.isEmpty
                    ? allLogos
                    : allLogos
                        .where((logo) =>
                            logo.name
                                .toLowerCase()
                                .contains(_searchController.text.toLowerCase()) ||
                            logo.slug
                                .toLowerCase()
                                .contains(_searchController.text.toLowerCase()))
                        .toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  // MaxCrossAxisExtent statt fester Spaltenanzahl: so bleibt
                  // jede Kachel höchstens 72dp breit, egal wie breit das
                  // Dialogfenster ist (z.B. auf dem Desktop). Eine feste
                  // mainAxisExtent (statt childAspectRatio) sorgt zusätzlich
                  // dafür, dass jede Kachel IMMER genug Höhe für Icon + Text
                  // hat, unabhängig von der (ggf. sehr schmalen) Breite -
                  // das hat zuvor den Overflow verursacht.
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 72,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 92,
                  ),
                  itemCount: filteredLogos.length,
                  itemBuilder: (context, index) {
                    final logo = filteredLogos[index];
                    final isSelected = _selectedLogo?.slug == logo.slug;

                    return GestureDetector(
                      // Eindeutiger Key pro Logo: verhindert, dass beim Filtern
                      // (Suche) ein bereits geladenes SVG-Bild (z.B. Netflix)
                      // an derselben Grid-Position für ein anderes Logo
                      // (z.B. HBO Max) weiterverwendet/angezeigt wird.
                      key: ValueKey(logo.slug),
                      onTap: () {
                        setState(() {
                          _selectedLogo = logo;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? const Color(0xFF6366F1).withOpacity(0.1)
                              : Colors.white,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo SVG Preview
                            Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Color(int.parse('0xff${logo.hex.substring(1)}')).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SafeSvgLogo(
                                key: ValueKey(logo.slug),
                                url: logo.url,
                                color: Color(int.parse('0xff${logo.hex.substring(1)}')),
                                fallbackLetter: logo.name.isNotEmpty ? logo.name.substring(0, 1).toUpperCase() : '?',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              logo.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Divider
          const Divider(height: 1),
          // Footer Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onLogoSelected(null);
                  },
                  child: const Text('Abbrechen'),
                ),
                if (_selectedLogo != null)
                  ElevatedButton(
                    onPressed: () {
                      widget.onLogoSelected(_selectedLogo);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Wählen'),
                  )
                else
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text('Wählen'),
                  ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
