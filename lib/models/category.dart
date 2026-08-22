class WallosCategory {
  final int id;
  final String name;

  WallosCategory({required this.id, required this.name});

  factory WallosCategory.fromJson(Map<String, dynamic> json) {
    return WallosCategory(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? 'Unbekannt',
    );
  }
}
