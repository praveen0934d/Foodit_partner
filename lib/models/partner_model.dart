class PartnerUser {
  final String id;
  final String name;
  final String email;
  final String restaurantId;
  final String token;

  PartnerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.restaurantId,
    required this.token,
  });

  factory PartnerUser.fromJson(Map<String, dynamic> json, String token) {
    return PartnerUser(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      restaurantId: json['restaurant_id']?.toString() ?? '', // Links user to their specific restaurant
      token: token,
    );
  }
}
