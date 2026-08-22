class WallosPaymentMethod {
  final int id;
  final String name;

  WallosPaymentMethod({required this.id, required this.name});

  factory WallosPaymentMethod.fromJson(Map<String, dynamic> json) {
    return WallosPaymentMethod(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? 'Unbekannt',
    );
  }
}
