class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // client | courier | admin
  final String phone;
  final String? vehicle;
  final bool online;
  final double rating;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.vehicle,
    this.online = false,
    this.rating = 5,
  });

  bool get isCourier => role == 'courier';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? 'client',
        phone: j['phone'] as String? ?? '',
        vehicle: j['vehicle'] as String?,
        online: j['online'] as bool? ?? false,
        rating: (j['rating'] as num?)?.toDouble() ?? 5,
      );
}
