class WallosHouseholdMember {
  final int id;
  final String name;

  WallosHouseholdMember({required this.id, required this.name});

  factory WallosHouseholdMember.fromJson(Map<String, dynamic> json) {
    return WallosHouseholdMember(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Unbekannt',
    );
  }
}
