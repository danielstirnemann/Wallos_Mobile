import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/subscription_provider.dart';
import 'widgets/gradient_card.dart';
import 'widgets/compact_list_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// Plant einen Refresh um Mitternacht ein
  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = midnight.difference(now);

    _midnightTimer?.cancel();
    _midnightTimer = Timer(durationUntilMidnight, () {
      if (mounted) {
        // Refresh Dashboard bei Mitternacht
        ref.invalidate(subscriptionProvider);
        
        // Plane nächsten Refresh ein
        _scheduleMidnightRefresh();
      }
    });
  }

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
  
  /// Rechnet ein Zahlungsdatum um [steps] Zahlungsintervalle (cycle/frequency
  /// des Abos) weiter (steps > 0) oder zurück (steps < 0).
  DateTime _shiftByCycle(DateTime date, int cycle, int frequency, int steps) {
    final freq = frequency > 0 ? frequency : 1;
    switch (cycle) {
      case 1: // täglich
        return date.add(Duration(days: freq * steps));
      case 2: // wöchentlich
        return date.add(Duration(days: 7 * freq * steps));
      case 4: // jährlich
        return DateTime(date.year + freq * steps, date.month, date.day);
      case 3: // monatlich
      default:
        final totalMonths = (date.year * 12 + (date.month - 1)) + freq * steps;
        final newYear = totalMonths ~/ 12;
        final newMonth = totalMonths % 12 + 1;
        // Tag beibehalten, aber auf den letzten Tag des Zielmonats begrenzen
        // (z.B. 31. Januar -> 28./29. Februar)
        final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;
        return DateTime(newYear, newMonth, newDay);
    }
  }

  /// Summiert die tatsächlich fälligen Beträge aller Abos, die im
  /// Kalendermonat [year]-[month] abgerechnet werden. Anders als eine reine
  /// Durchschnittsrechnung (siehe [_priceToMonthly]) werden dabei die
  /// tatsächlichen Zahlungstermine (ausgehend vom gespeicherten
  /// "nächste Zahlung"-Datum, im Rhythmus von cycle/frequency vor- und
  /// zurückgerechnet) betrachtet - inklusive mehrerer Termine pro Monat bei
  /// täglichem/wöchentlichem Rhythmus.
  double _costForMonth(List subscriptions, int year, int month) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1); // exklusiv

    double total = 0;
    for (var sub in subscriptions) {
      final nextPayment = DateTime.tryParse(sub.nextPayment);
      if (nextPayment == null) continue;

      if (sub.cycle == 5) {
        // Einmalig: keine Wiederholung
        if (!nextPayment.isBefore(monthStart) && nextPayment.isBefore(monthEnd)) {
          total += sub.price;
        }
        continue;
      }

      // Ausgehend vom gespeicherten Zahlungstermin zunächst zurückrechnen,
      // bis wir vor dem Zielmonat liegen ...
      var occurrence = nextPayment;
      var safety = 0;
      while (occurrence.isAfter(monthStart) && safety < 500) {
        occurrence = _shiftByCycle(occurrence, sub.cycle, sub.frequency, -1);
        safety++;
      }
      // ... und dann vorwärts alle Termine aufsummieren, die in den
      // Zielmonat fallen (kann bei täglich/wöchentlich mehrfach zutreffen).
      safety = 0;
      while (occurrence.isBefore(monthEnd) && safety < 500) {
        if (!occurrence.isBefore(monthStart)) {
          total += sub.price;
        }
        occurrence = _shiftByCycle(occurrence, sub.cycle, sub.frequency, 1);
        safety++;
      }
    }

    return total;
  }

  /// Baut den Monatlichen Vergleich (diesen vs nächsten Monat) Widget
  Widget _buildMonthlyComparison(BuildContext context, List subscriptions) {
    final today = DateTime.now();
    final currentMonth = today.month;
    final currentYear = today.year;
    final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
    final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;

    // Tatsächlich fällige Beträge für diesen und nächsten Kalendermonat
    // (basierend auf den echten Zahlungsterminen, nicht auf dem
    // amortisierten Monatsdurchschnitt).
    final currentMonthTotal = _costForMonth(subscriptions, currentYear, currentMonth);
    final nextMonthTotal = _costForMonth(subscriptions, nextYear, nextMonth);

    final monthNames = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final currentMonthName = monthNames[currentMonth];
    final nextMonthName = monthNames[nextMonth];
    
    return Row(
      children: [
        // Dieser Monat (Gradient)
        Expanded(
          child: GradientCard(
            title: currentMonthName,
            value: '${currentMonthTotal.toStringAsFixed(2)} CHF',
            icon: Icons.calendar_month,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.cyan.shade400,
                Colors.blue.shade600,
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Nächster Monat (Gradient)
        Expanded(
          child: GradientCard(
            title: nextMonthName,
            value: '${nextMonthTotal.toStringAsFixed(2)} CHF',
            icon: Icons.calendar_month,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade400,
                Colors.cyan.shade600,
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Baut die nächsten 3 Zahlungen Widget (kompakte Listen-Ansicht)
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
      children: [
        for (int i = 0; i < upcoming.length; i++) ...
          [
            CompactListCard(
              title: upcoming[i].name,
              value: '${upcoming[i].price.toStringAsFixed(2)} CHF',
              subtitle: _formatPaymentSubtitle(upcoming[i].nextPayment),
              icon: Icons.calendar_today,
              accentColor: _getPaymentColor(i),
            ),
            if (i < upcoming.length - 1) const SizedBox(height: 8),
          ]
      ],
    );
  }
  
  /// Formatiert das Zahlungs-Datum für die Anzeige
  String _formatPaymentSubtitle(String nextPayment) {
    final paymentDate = DateTime.tryParse(nextPayment);
    if (paymentDate == null) return nextPayment;
    
    final formattedDate = '${paymentDate.day.toString().padLeft(2, '0')}.${paymentDate.month.toString().padLeft(2, '0')}.${paymentDate.year}';
    final daysUntil = paymentDate.difference(DateTime.now()).inDays;
    
    final daysLabel = daysUntil == 0
        ? 'Heute'
        : daysUntil == 1
            ? 'Morgen'
            : daysUntil < 0
                ? '${daysUntil.abs()} Tage überfällig'
                : 'in $daysUntil Tagen';
    
    return '$formattedDate • $daysLabel';
  }
  
  /// Gibt die Farbe basierend auf Position zurück
  Color _getPaymentColor(int index) {
    switch (index) {
      case 0: return const Color(0xFFEF4444);  // Rot
      case 1: return const Color(0xFFF59E0B);  // Amber
      case 2: return const Color(0xFF8B5CF6);  // Lila
      default: return const Color(0xFF6366F1); // Indigo
    }
  }
  
  /// Formatiert Subtitle für Top Abos
  String _buildTopAboSubtitle(dynamic sub) {
    final cycleLabel = _getCycleLabel(sub.cycle);
    final monthlyPrice = _priceToMonthly(sub.price, sub.cycle);
    return '$cycleLabel • ${monthlyPrice.toStringAsFixed(2)} CHF/Monat';
  }
  
  /// Gibt Farbe für Top Abo basierend auf Position zurück
  Color _getTopAboColor(int index) {
    switch (index) {
      case 0: return const Color(0xFF8B5CF6);  // Lila
      case 1: return const Color(0xFF06B6D4);  // Cyan
      case 2: return const Color(0xFFF59E0B);  // Amber
      default: return const Color(0xFF6366F1); // Indigo
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final subAsync = ref.watch(subscriptionProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(subscriptionProvider);
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
                  
                  // Monatliche Ausgaben für diesen und nächsten Monat (Gradient Cards)
                  _buildMonthlyComparison(context, activeSubscriptions),
                  const SizedBox(height: 16),
                  
                  // Durchschnittliche monatliche Ausgaben (Gradient)
                  GradientCard(
                    title: 'Durchschnittlich pro Monat',
                    value: '${totalMonthly.toStringAsFixed(2)} CHF',
                    subtitle: '${activeSubscriptions.length} aktive Abos',
                    icon: Icons.trending_up,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade400,
                        Colors.purple.shade600,
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Jährliche Ausgaben (Gradient)
                  GradientCard(
                    title: 'Jährliche Ausgaben',
                    value: '${totalYearly.toStringAsFixed(2)} CHF',
                    subtitle: 'Pro Jahr',
                    icon: Icons.calendar_today,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.amber.shade400,
                        Colors.orange.shade600,
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nächste Zahlungen Section
                  Text(
                    'Nächste Zahlungen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingPayments(context, activeSubscriptions),
                  const SizedBox(height: 20),

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
                      children: [
                        for (int i = 0; i < topAbos.length; i++) ...
                          [
                            CompactListCard(
                              title: topAbos[i].name,
                              value: '${topAbos[i].price.toStringAsFixed(2)} CHF',
                              subtitle: _buildTopAboSubtitle(topAbos[i]),
                              icon: Icons.shopping_bag,
                              accentColor: _getTopAboColor(i),
                            ),
                            if (i < topAbos.length - 1) const SizedBox(height: 8),
                          ]
                      ],
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
