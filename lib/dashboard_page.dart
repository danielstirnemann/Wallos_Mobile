import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/subscription_provider.dart';
import 'widgets/dashboard_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  /// Konvertiert cycle-ID zu lesbarem Text
  /// 1=täglich, 2=wöchentlich, 3=monatlich, 4=jährlich, 5=einmalig
  String _getCycleLabel(int cycle) {
    switch (cycle) {
      case 1:
        return 'täglich';
      case 2:
        return 'wöchentlich';
      case 3:
        return 'monatlich';
      case 4:
        return 'jährlich';
      case 5:
        return 'einmalig';
      default:
        return 'unbekannt';
    }
  }
  
  /// Konvertiert Preis + cycle zu monatlichem Betrag
  /// cycle: 1=täglich, 2=wöchentlich, 3=monatlich, 4=jährlich, 5=einmalig
  double _priceToMonthly(double price, int cycle) {
    switch (cycle) {
      case 1: return price * 30;        // täglich → monatlich (×30 Tage)
      case 2: return price * 4.33;      // wöchentlich → monatlich (×4.33 Wochen)
      case 3: return price;             // monatlich = monatlich
      case 4: return price / 12;        // jährlich → monatlich (/12)
      case 5: return 0;                 // einmalig = ignorieren
      default: return price;
    }
  }
  
  /// Baut den Monatlichen Vergleich (diesen vs nächsten Monat) Widget
  Widget _buildMonthlyComparison(BuildContext context, List subscriptions) {
    final today = DateTime.now();
    final currentMonth = today.month;
    final currentYear = today.year;
    final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
    final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;
    
    // Berechne Ausgaben für diesen Monat
    double currentMonthTotal = 0;
    double nextMonthTotal = 0;
    
    for (var sub in subscriptions) {
      final paymentDate = DateTime.tryParse(sub.nextPayment);
      if (paymentDate == null) continue;
      
      // Preis zum Monat hinzufügen wenn Zahlung in diesem Monat oder jähnlich erfolgt
      final monthlyPrice = _priceToMonthly(sub.price, sub.cycle);
      
      // Vereinfachte Logik: Wenn nächste Zahlung im aktuellen Monat, zähle alle bis Ende Monat
      if (paymentDate.month == currentMonth && paymentDate.year == currentYear) {
        currentMonthTotal += monthlyPrice;
      } else if (paymentDate.month == nextMonth && paymentDate.year == nextYear) {
        nextMonthTotal += monthlyPrice;
      }
    }
    
    // Falls Berechnung leer, nutze monatliche Ausgaben als Fallback
    if (currentMonthTotal == 0) {
      currentMonthTotal = subscriptions.fold(
        0.0,
        (sum, sub) => sum + _priceToMonthly(sub.price, sub.cycle),
      );
    }
    if (nextMonthTotal == 0) {
      nextMonthTotal = subscriptions.fold(
        0.0,
        (sum, sub) => sum + _priceToMonthly(sub.price, sub.cycle),
      );
    }
    
    final monthNames = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final currentMonthName = monthNames[currentMonth];
    final nextMonthName = monthNames[nextMonth];
    
    return Row(
      children: [
        // Dieser Monat
        Expanded(
          child: DashboardCard(
            title: currentMonthName,
            value: '${currentMonthTotal.toStringAsFixed(2)} CHF',
            icon: Icons.calendar_month,
            backgroundColor: Colors.blue.shade50,
          ),
        ),
        const SizedBox(width: 8),
        
        // Nächster Monat
        Expanded(
          child: DashboardCard(
            title: nextMonthName,
            value: '${nextMonthTotal.toStringAsFixed(2)} CHF',
            icon: Icons.calendar_month,
            backgroundColor: Colors.blue.shade100,
          ),
        ),
      ],
    );
  }
  
  /// Baut die nächsten 3 Zahlungen Widget
  Widget _buildUpcomingPayments(BuildContext context, List subscriptions) {
    // Sortiere nach nächstem Zahlungsdatum
    final upcoming = List.from(subscriptions)
      ..sort((a, b) => a.nextPayment.compareTo(b.nextPayment))
      ..take(3)
      .toList();

    if (upcoming.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Keine anstehenden Zahlungen'),
      );
    }

    return Column(
      children: upcoming.map((sub) {
        final paymentDate = DateTime.tryParse(sub.nextPayment);
        final formattedDate = paymentDate != null
            ? '${paymentDate.day.toString().padLeft(2, '0')}.${paymentDate.month.toString().padLeft(2, '0')}.${paymentDate.year}'
            : sub.nextPayment;
        
        // Berechne Tage bis Zahlung
        final daysUntil = paymentDate?.difference(DateTime.now()).inDays ?? 0;
        final daysLabel = daysUntil == 0
            ? 'Heute'
            : daysUntil == 1
                ? 'Morgen'
                : 'in $daysUntil Tagen';

        return DashboardCard(
          title: sub.name,
          value: '${sub.price.toStringAsFixed(2)} CHF',
          subtitle: '$formattedDate ($daysLabel)',
          icon: Icons.calendar_today,
          backgroundColor: Colors.red.shade50,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // ignore: unused_result
        ref.refresh(subscriptionProvider);
        return Future.value();
      },
      child: subAsync.when(
        data: (subscriptions) {
          // Filtere nur aktive Abos (inactive=0)
          final activeSubscriptions = subscriptions.where((sub) => sub.inactive == 0).toList();
          
          // Berechne monatliche Ausgaben (nur aktive)
          // cycle ist eine ID: 1=täglich, 2=wöchentlich, 3=monatlich, 4=jährlich, 5=einmalig
          final totalMonthly = activeSubscriptions.fold<double>(
            0,
            (sum, sub) => sum + _priceToMonthly(sub.price, sub.cycle),
          );
          
          final totalYearly = totalMonthly * 12;
          
          // Sortiere nach Preis (teuerste zuerst)
          final topAbos = List.from(activeSubscriptions)
            ..sort((a, b) => b.price.compareTo(a.price))
            ..take(3)
            .toList();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gesamt-Ausgaben Section
                  Text(
                    'Ausgaben',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  
                  // Monatliche Ausgaben für diesen und nächsten Monat (Side by Side)
                  _buildMonthlyComparison(context, activeSubscriptions),
                  const SizedBox(height: 12),
                  
                  // Durchschnittliche monatliche Ausgaben
                  DashboardCard(
                    title: 'Durchschnittlich pro Monat',
                    value: '${totalMonthly.toStringAsFixed(2)} CHF',
                    icon: Icons.trending_up,
                    backgroundColor: Colors.purple.shade50,
                  ),
                  const SizedBox(height: 12),
                  
                  // Jährliche Ausgaben
                  DashboardCard(
                    title: 'Jährliche Ausgaben',
                    value: '${totalYearly.toStringAsFixed(2)} CHF',
                    icon: Icons.calendar_today,
                    backgroundColor: Colors.orange.shade50,
                  ),
                  const SizedBox(height: 24),

                  // Nächste Zahlungen Section
                  Text(
                    'Nächste Zahlungen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingPayments(context, activeSubscriptions),
                  const SizedBox(height: 24),

                  // Top Abos Section
                  Text(
                    'Teuerste Abos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  
                  if (topAbos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Keine Abos vorhanden'),
                    )
                  else
                    Column(
                      children: topAbos.map((sub) {
                        final cycleLabel = _getCycleLabel(sub.cycle);
                        final monthlyPrice = _priceToMonthly(sub.price, sub.cycle);
                        return DashboardCard(
                          title: sub.name,
                          value: '${sub.price.toStringAsFixed(2)} CHF',
                          subtitle: '$cycleLabel (${monthlyPrice.toStringAsFixed(2)} CHF/Monat)',
                          icon: Icons.shopping_bag,
                          backgroundColor: Colors.purple.shade50,
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Section
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[900]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${activeSubscriptions.length} aktive Abonnemente',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Fehler beim Laden: $err'),
            ],
          ),
        ),
      ),
    );
  }
}
