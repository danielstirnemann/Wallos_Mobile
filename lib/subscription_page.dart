import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/subscription_provider.dart';
import 'utils/subscription_dialog_handler.dart';
import 'widgets/subscription_list.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  final VoidCallback? onGoToSettings;

  const SubscriptionPage({super.key, this.onGoToSettings});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showInactive = false;  // Wieder lokaler State

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionProvider);

    return Column(
      children: [
        // Suchleiste + Toggle
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Abos durchsuchen...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showInactive ? Icons.visibility_off : Icons.visibility,
                  color: _showInactive ? Colors.orange : Colors.grey,
                ),
                tooltip: _showInactive ? 'Aktive zeigen' : 'Inaktive zeigen',
                onPressed: () => setState(() => _showInactive = !_showInactive),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Abo hinzufügen',
                // WICHTIG: Die Wallos-Verbindung ist komplett optional - Abos
                // können jederzeit rein lokal angelegt werden (siehe
                // defaultLocalCurrencies/defaultLocalCategories im
                // "Abo hinzufügen"-Dialog). Hier darf daher KEINE Blockade
                // mehr erfolgen, nur weil (noch) keine Wallos-Verbindung
                // eingerichtet ist.
                onPressed: () {
                  SubscriptionDialogHandler.showAddDialog(
                    context,
                    ref,
                  );
                },
              ),
            ],
          ),
        ),
        // Abos Liste
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(subscriptionProvider);
              return Future.value();
            },
            child: subAsync.when(
              data: (subscriptions) {
                // Filtere zuerst nach aktiv/inaktiv Status
                final statusFilteredSubscriptions = subscriptions
                    .where((sub) =>
                        _showInactive ? sub.inactive == 1 : sub.inactive == 0)
                    .toList();

                // Dann nach Suchquery
                final filteredSubscriptions = statusFilteredSubscriptions
                    .where((sub) =>
                        sub.name.toLowerCase().contains(_searchQuery))
                    .toList();

                // Zeige "Keine Ergebnisse" wenn leer UND gesucht wird
                if (filteredSubscriptions.isEmpty && _searchQuery.isNotEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Keine Abos gefunden',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Zeige eine freundliche Leer-Ansicht, wenn (unabhängig von
                // Wallos) schlicht noch KEIN Abo angelegt wurde - z.B. direkt
                // nach der Erstinstallation.
                if (filteredSubscriptions.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showInactive ? Icons.visibility_off : Icons.receipt_long,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _showInactive
                                    ? 'Keine inaktiven Abos vorhanden'
                                    : 'Noch keine Abos vorhanden',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              if (!_showInactive) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Text(
                                    'Tippe oben rechts auf "+", um dein erstes Abo hinzuzufügen.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SubscriptionList(
                  subscriptions: filteredSubscriptions,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Center(child: Text('Fehler: $err')),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
