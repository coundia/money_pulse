/* DTO for Company delta push payload. */
class CompanyDeltaDto {
  final String id;
  final String type;
  final String code;
  final String? name;
  final String? remoteId;
  final String? description;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxId;
  final String? currency;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? region;
  final String? country;
  final String? postalCode;
  final bool isDefault;
  final int version;
  final String? syncAt;

  const CompanyDeltaDto({
    required this.id,
    required this.type,
    required this.code,
    this.name,
    this.remoteId,
    this.description,
    this.phone,
    this.email,
    this.website,
    this.taxId,
    this.currency,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.region,
    this.country,
    this.postalCode,
    required this.isDefault,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'code': code,
    'name': name,
    'remoteId': remoteId,
    'description': description,
    'phone': phone,
    'email': email,
    'website': website,
    'taxId': taxId,
    'currency': currency,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city': city,
    'region': region,
    'country': country,
    'postalCode': postalCode,
    'isDefault': isDefault,
    'version': version,
    'syncAt': syncAt,
  };
}
