class WallosCurrency {
  final int id;
  final String name;
  final String symbol;

  WallosCurrency({required this.id, required this.name, required this.symbol});

  factory WallosCurrency.fromJson(Map<String, dynamic> json) {
    return WallosCurrency(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? 'Unbekannt',
      symbol: json['symbol'] ?? '',
    );
  }
}
