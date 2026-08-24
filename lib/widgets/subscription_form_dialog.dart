import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../providers/default_subscription_settings_provider.dart';
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
  int? _selectedPayer;
  late int _selectedCycle;
  late int _selectedFrequency;

  // Verhindert, dass der konfigurierte Standard-Zyklus bei jedem Rebuild
  // erneut angewendet wird (z.B. nachdem der Nutzer den Zyklus manuell
  // geändert hat). Nur relevant beim Hinzufügen eines NEUEN Abos.
  bool _appliedConfiguredCycleDefault = false;

  LogoItem? _selectedLogoItem;

  @override
  void initState() {
    super.initState();
    final existing = widget.subscription;

    // Zyklus-IDs entsprechen der Wallos-API: 1=täglich, 2=wöchentlich,
    // 3=monatlich, 4=jährlich, 5=einmalig.
    //
    // WICHTIG: Beim Bearbeiten eines bestehenden Abos müssen Zyklus,
    // Häufigkeit, Währung, Kategorie und Zahlungsmethode mit den
    // vorhandenen Werten vorbefüllt werden - sonst würde beim Speichern
    // (auch ohne dass der Nutzer diese Felder anfasst) stillschweigend
    // wieder auf den Standardwert zurückgesetzt (z.B. ein jährliches Abo
    // würde beim nächsten Bearbeiten plötzlich "Monatlich").
    _selectedCycle = existing?.cycle ?? 3; // 3 = Monatlich (Standard für neue Abos)
    _selectedFrequency = existing?.frequency ?? 1;
    _selectedCurrency = existing?.currencyId;
    _selectedCategory = existing?.categoryId;
    _selectedPaymentMethod = existing?.paymentMethodId;
    _selectedPayer = existing?.payerUserId;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _priceController = TextEditingController(text: existing?.price.toString() ?? '');
    _nextPaymentController = TextEditingController(
      text: (existing != null && existing.nextPayment.isNotEmpty)
          ? existing.nextPayment
          : DateTime.now().toString().split(' ')[0],
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

    // Kategorie ist bewusst NICHT (mehr) zwingend erforderlich - die App
    // soll auch ohne Wallos-Verbindung (und damit ohne konfigurierbare
    // Kategorien) vollständig eigenständig nutzbar sein. Währung bleibt
    // erforderlich, ist aber dank der eingebauten Standard-Währungsliste
    // (siehe defaultLocalCurrencies) auch offline immer verfügbar.
    if (_selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Währung wählen')),
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
      'payer_user_id': _selectedPayer,
      'cycle': _selectedCycle,
      'frequency': _selectedFrequency,
      'next_payment': _nextPaymentController.text,
      'logo_url': _selectedLogoItem?.url,
      'logo_hex': _selectedLogoItem?.hex,
    });
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(metaDataProvider);
    final isAdding = widget.subscription == null;
    // Nur beim Hinzufügen eines neuen Abos relevant - die in den
    // Einstellungen konfigurierten Standardwerte. Wir beobachten hier den
    // vollen AsyncValue (nicht nur `.value`), damit wir erkennen können, ob
    // die Standardwerte NOCH laden - siehe Kommentar weiter unten, warum das
    // wichtig ist.
    final defaultsAsync = isAdding ? ref.watch(defaultSubscriptionSettingsProvider) : null;
    // WICHTIG: Solange die konfigurierten Standardwerte noch laden (erster
    // Aufruf von SharedPreferences ist async), darf die "Fallback auf
    // erster Eintrag"-Logik unten NICHT bereits greifen - sonst wird
    // _selectedCurrency/_selectedCategory/... bereits auf den ersten
    // verfügbaren Eintrag gesetzt, BEVOR die eigentlich konfigurierten
    // Standardwerte ankommen. Da die Felder danach nicht mehr `null` sind,
    // würden die konfigurierten Standardwerte nie mehr angewendet werden.
    final waitingForDefaults = isAdding && (defaultsAsync?.isLoading ?? false);
    final configuredDefaults = defaultsAsync?.value;

    return AlertDialog(
      title: Text(isAdding ? 'Abo hinzufügen' : 'Abo bearbeiten'),
      content: waitingForDefaults
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : metaAsync.when(
        data: (meta) {
          // Falls die aktuell ausgewählte Währung/Kategorie in der JETZT
          // verfügbaren Liste nicht mehr existiert (z.B. eine lokale
          // Standardauswahl von VOR dem Verbinden mit Wallos, oder eine
          // Wallos-Kategorie, die zwischenzeitlich gelöscht wurde), muss die
          // Auswahl zurücksetzt werden - sonst würde das DropdownButtonFormField
          // versuchen, einen nicht vorhandenen Wert darzustellen.
          if (_selectedCurrency != null && !meta.currencies.any((c) => c.id == _selectedCurrency)) {
            _selectedCurrency = null;
          }
          if (_selectedCategory != null && !meta.categories.any((c) => c.id == _selectedCategory)) {
            _selectedCategory = null;
          }

          // Setze Standardwerte, falls noch nichts ausgewählt ist. Beim
          // Hinzufügen wird bevorzugt der in den Einstellungen konfigurierte
          // Standard verwendet (sofern er noch existiert), sonst der erste
          // verfügbare Eintrag.
          if (_selectedCurrency == null) {
            final preferred = configuredDefaults?.currencyId;
            if (preferred != null && meta.currencies.any((c) => c.id == preferred)) {
              _selectedCurrency = preferred;
            } else if (meta.currencies.isNotEmpty) {
              _selectedCurrency = meta.currencies.first.id;
            }
          }
          if (_selectedCategory == null) {
            final preferred = configuredDefaults?.categoryId;
            if (preferred != null && meta.categories.any((c) => c.id == preferred)) {
              _selectedCategory = preferred;
            } else if (meta.categories.isNotEmpty) {
              _selectedCategory = meta.categories.first.id;
            }
          }
          if (_selectedPaymentMethod == null) {
            final preferred = configuredDefaults?.paymentMethodId;
            if (preferred != null && meta.paymentMethods.any((pm) => pm.id == preferred)) {
              _selectedPaymentMethod = preferred;
            } else if (meta.paymentMethods.isNotEmpty) {
              _selectedPaymentMethod = meta.paymentMethods.first.id;
            }
          }
          if (_selectedPayer == null) {
            final preferred = configuredDefaults?.payerUserId;
            if (preferred != null && meta.householdMembers.any((m) => m.id == preferred)) {
              _selectedPayer = preferred;
            } else if (meta.householdMembers.isNotEmpty) {
              _selectedPayer = meta.householdMembers.first.id;
            }
          }
          if (isAdding && !_appliedConfiguredCycleDefault && configuredDefaults != null) {
            _selectedCycle = configuredDefaults.cycle;
            _appliedConfiguredCycleDefault = true;
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
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Währung',
                    border: OutlineInputBorder(),
                  ),
                  items: meta.currencies.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.name} (${c.symbol})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCurrency = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: meta.categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 16),
                // Ohne Wallos-Verbindung (bzw. solange der Server nicht
                // erreichbar ist) gibt es keine Zahlungsmethoden - anders als
                // Währung/Kategorie hat dieses Feld bewusst KEINE eingebaute
                // lokale Fallback-Liste (Zahlungsmethoden sind sehr
                // Wallos-Account-spezifisch). Daher wird das Dropdown analog
                // zu "Zahler" nur angezeigt, wenn tatsächlich welche verfügbar
                // sind - ein leeres, nicht nutzbares Dropdown wäre verwirrend.
                if (meta.paymentMethods.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedPaymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Zahlungsmethode',
                      border: OutlineInputBorder(),
                    ),
                    items: meta.paymentMethods.map((pm) => DropdownMenuItem(
                      value: pm.id,
                      child: Text(pm.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedPaymentMethod = value),
                  ),
                  const SizedBox(height: 16),
                ],
                if (meta.householdMembers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _selectedPayer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Zahler',
                      border: OutlineInputBorder(),
                    ),
                    items: meta.householdMembers.map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedPayer = value),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCycle,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Zyklus',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Täglich')),
                    DropdownMenuItem(value: 2, child: Text('Wöchentlich')),
                    DropdownMenuItem(value: 3, child: Text('Monatlich')),
                    DropdownMenuItem(value: 4, child: Text('Jährlich')),
                    DropdownMenuItem(value: 5, child: Text('Einmalig')),
                  ],
                  onChanged: (value) => setState(() => _selectedCycle = value ?? 3),
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

