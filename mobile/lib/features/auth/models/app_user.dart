class DriverProfile {
  DriverProfile({required this.vehicleType, this.plateNumber, required this.verificationStatus, required this.isActive, required this.isOnline});

  final String vehicleType;
  final String? plateNumber;
  final String verificationStatus; // pending, verified, rejected
  final bool isActive;
  final bool isOnline;

  bool get isVerified => verificationStatus == 'verified';

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        vehicleType: j['vehicle_type'] ?? 'motorbike',
        plateNumber: j['plate_number'],
        verificationStatus: j['verification_status'] ?? 'pending',
        isActive: j['is_active'] == true,
        isOnline: j['is_online'] == true,
      );
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.universityId,
    this.userType,
    this.phone,
    this.avatarUrl,
    this.driverProfile,
  });

  final String id;
  final String name;
  final String email;
  final String role; // customer, driver, store_owner, admin
  final String? universityId;
  final String? userType; // student, lecturer, staff
  final String? phone;
  final String? avatarUrl;
  final DriverProfile? driverProfile;

  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
  }

  String get typeLabel => switch (userType) {
        'lecturer' => 'Lecturer',
        'staff' => 'Staff',
        'student' => 'Student',
        _ => role == 'driver' ? 'Driver' : 'Customer',
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? 'customer',
        universityId: j['university_id'],
        userType: j['user_type'],
        phone: j['phone'],
        avatarUrl: j['avatar_url'],
        driverProfile: j['driver_profile'] is Map ? DriverProfile.fromJson((j['driver_profile'] as Map).cast()) : null,
      );
}
