/* DTO for Customer delta push payload. */
class CustomerDeltaDto {
  final String id;
  final String type;
  final String? remoteId;
  final String? code;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final int balance;
  final int balanceDebt;
  final String? phone;
  final String? email;
  final String? notes;
  final String? status;
  final String? companyId;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? region;
  final String? country;
  final String? postalCode;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int version;
  final String? syncAt;

  const CustomerDeltaDto({
    required this.id,
    required this.type,
    this.remoteId,
    this.code,
    this.firstName,
    this.lastName,
    this.fullName,
    required this.balance,
    required this.balanceDebt,
    this.phone,
    this.email,
    this.notes,
    this.status,
    this.companyId,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.region,
    this.country,
    this.postalCode,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'remoteId': remoteId,
    'code': code,
    'firstName': firstName,
    'lastName': lastName,
    'fullName': fullName,
    'balance': balance,
    'balanceDebt': balanceDebt,
    'phone': phone,
    'email': email,
    'notes': notes,
    'status': status,
    'companyId': companyId,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city': city,
    'region': region,
    'country': country,
    'postalCode': postalCode,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
    'version': version,
    'syncAt': syncAt,
  };
}
