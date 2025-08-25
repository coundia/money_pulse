/* DTO for company deltas: builds JSON payload with UTC ISO-8601 dates for push. */
import 'package:money_pulse/sync/domain/sync_delta_type.dart';

import '../../../domain/company/entities/company.dart';

class CompanyDeltaDto {
  final String id;
  final String? remoteId;
  final String? localId;
  final String? code;
  final String? name;
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
  final String type;
  final DateTime updatedAt;

  CompanyDeltaDto({
    required this.id,
    this.remoteId,
    this.localId,
    this.code,
    this.name,
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
    required this.type,
    required this.updatedAt,
  });

  factory CompanyDeltaDto.fromEntity(Company c, SyncDeltaType t, DateTime now) {
    return CompanyDeltaDto(
      id: c.id,
      remoteId: c.remoteId,
      localId: c.localId,
      code: c.code,
      name: c.name,
      description: c.description,
      phone: c.phone,
      email: c.email,
      website: c.website,
      taxId: c.taxId,
      currency: c.currency,
      addressLine1: c.addressLine1,
      addressLine2: c.addressLine2,
      city: c.city,
      region: c.region,
      country: c.country,
      postalCode: c.postalCode,
      isDefault: c.isDefault,
      type: t.name,
      updatedAt: now,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'remoteId': remoteId,
    'localId': localId,
    'code': code,
    'name': name,
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
    'operation': type,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
