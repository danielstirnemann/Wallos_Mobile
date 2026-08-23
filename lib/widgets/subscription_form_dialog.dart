import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../providers/meta_provider.dart';
import '../services/logo_service.dart';
import 'logo_picker_dialog.dart';
import 'safe_svg_logo.dart';

class SubscriptionFormDialog extends ConsumerStatefulWidget {
  final Subscription? subscription;
  final Function(Map<String, dynamic>) onSave;

  const SubscriptionFormDialog({
    super.key,
    this.subscription,
    required this.onSave,
  });

  @override
  ConsumerState<SubscriptionFormDialog> createState() => _SubscriptionFormDialogState();
}

class _SubscriptionFormDialogState extends ConsumerState<SubscriptionFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _nextPaymentController;

  int? _selectedCurrency;
  int? _selectedCategory;
  int? _selectedPaymentMethod;
  late int _selectedCycle;
  late int _selectedFrequency;
  
  LogoItem? _selectedLogoItem;
  final _logoService = LogoService();

  @override
  void initState() {
    super.initState();
    _selectedCycle = 1; // 1 = Monatlich
    _selectedFrequency = 1;
    
    _nameController = TextEditingController(text: widget.subscription?.name ?? '');
    _priceController = TextEditingController(text: widget.subscription?.price.toString() ?? '');
    _nextPaymentController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0]
    );

    // Beim Hinzufügen eines neuen Abos soll primär zuerst ein Logo gewählt
    // werden, damit der Name automatisch anhand des Logos vorausgefüllt wird.
    if (widget.subscription == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _selectLogo());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _nextPaymentController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _nextPaymentController.text = picked.toString().split(' ')[0];
      });
    }
  }
  
  void _selectLogo() async {
    final selected = await LogoPickerDialog.show(
      context,
      initialLogoSlug: _selectedLogoItem?.slug,
    );
    
    if (selected != null) {
      setState(() {
        _selectedLogoItem = selected;
        // Titel anhand des gewählten Logos vorausfüllen, solange der Name
        // noch nicht manuell (anders) gesetzt wurde.
        if (_nameController.text.isEmpty) {
          _nameController.text = selected.name;
        }
      });
    }
  }

  void _save() {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Name und Preis ausfüllen')),
      );
      return;
    }

    if (_selectedCurrency == null || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Währung und Kategorie wählen')),
      );
      return;
    }

    widget.onSave({
      'id': widget.subscription?.id,
      'name': _nameController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'currency_id': _selectedCurrency,
      'category_id': _selectedCategory,
      'payment_method_id': _selectedPaymentMethod,
      'cycle': _selectedCycle,
      'frequency': _selectedFrequency,
      'next_payment': _nextPaymentController.text,
      'logo_url': _selectedLogoItem?.url,
    });
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(metaDataProvider);

    return AlertDialog(
      title: Text(widget.subscription == null ? 'Abo hinzufügen' : 'Abo bearbeiten'),
      content: metaAsync.when(
        data: (meta) {
          // Setze Standardwerte, falls noch nichts ausgewählt ist
          if (_selectedCurrency == null && meta.currencies.isNotEmpty) {
            _selectedCurrency = meta.currencies.first.id;
          }
          if (_selectedCategory == null && meta.categories.isNotEmpty) {
            _selectedCategory = meta.categories.first.id;
          }
          if (_selectedPaymentMethod == null && meta.paymentMethods.isNotEmpty) {
            _selectedPaymentMethod = meta.paymentMethods.first.id;
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Picker Button (primär zuerst, füllt bei Auswahl den Namen vor)
                Row(
                  children: [
                    Expanded(
                      // Statt ElevatedButton.icon (dessen Label nicht
                      // schrumpft) bauen wir den Button selbst auf und
                      // umschließen das Label mit Flexible + Ellipsis, damit
                      // er bei wenig Platz (z.B. neben der Logo-Vorschau)
                      // nicht mehr in einen Overflow läuft.
                      child: ElevatedButton(
                        onPressed: _selectLogo,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.image, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Logo wählen',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedLogoItem != null) ...
                      [
                        const SizedBox(width: 12),
                        Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(
                                '0xff${_selectedLogoItem!.hex.substring(1)}',
                              ),
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SafeSvgLogo(
                            key: ValueKey(_selectedLogoItem!.slug),
                            url: _selectedLogoItem!.url,
                            color: Color(int.parse('0xff${_selectedLogoItem!.hex.substring(1)}')),
                            fallbackLetter: _selectedLogoItem!.name.isNotEmpty
                                ? _selectedLogoItem!.name.substring(0, 1).toUpperCase()
                                : '?',
                          ),
                        ),
                      ],
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Preis',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Währung',
                    border: OutlineInputBorder(),
                  ),
                  items: meta.currencies.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.name} (${c.symbol})'),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCurrency = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: meta.categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Zahlungsmethode',
                    border: OutlineInputBorder(),
                  ),
                  items: meta.paymentMethods.map((pm) => DropdownMenuItem(
                    value: pm.id,
                    child: Text(pm.name),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedPaymentMethod = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCycle,
                  decoration: const InputDecoration(
                    labelText: 'Zyklus',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monatlich')),
                    DropdownMenuItem(value: 3, child: Text('Vierteljährlich')),
                    DropdownMenuItem(value: 4, child: Text('Halbjährlich')),
                    DropdownMenuItem(value: 5, child: Text('Jährlich')),
                  ],
                  onChanged: (value) => setState(() => _selectedCycle = value ?? 1),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nextPaymentController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Nächste Zahlung',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Text('Fehler beim Laden der Wallos-Daten: $err'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

