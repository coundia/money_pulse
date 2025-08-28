// DTO for customer deltas sent to the API; ensures ISO-8601 UTC for dates.
import 'package:money_pulse/sync/domain/sync_delta_type.dart';

import '../../../domain/customer/entities/customer.dart';

class CustomerDeltaDto {
  final String id;
  final String? remoteId;
  final String? localId;
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
  final String? account;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? region;
  final String? country;
  final String? postalCode;
  final String type;
  final DateTime updatedAt;

  CustomerDeltaDto({
    required this.id,
    this.remoteId,
    this.localId,
    this.code,
    this.firstName,
    this.lastName,
    this.account,
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
    required this.type,
    required this.updatedAt,
  });

  factory CustomerDeltaDto.fromEntity(
    Customer c,
    SyncDeltaType t,
    DateTime now,
  ) {
    return CustomerDeltaDto(
      id: c.id,
      remoteId: c.remoteId,
      localId: c.localId,
      code: c.code,
      firstName: c.firstName,
      lastName: c.lastName,
      fullName: c.fullName,
      balance: c.balance,
      balanceDebt: c.balanceDebt,
      phone: c.phone,
      email: c.email,
      notes: c.notes,
      status: c.status,
      companyId: c.companyId,
      addressLine1: c.addressLine1,
      addressLine2: c.addressLine2,
      city: c.city,
      region: c.region,
      account: c.account,
      country: c.country,
      postalCode: c.postalCode,
      type: t.name,
      updatedAt: now,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'remoteId': remoteId,
    'localId': localId,
    'code': code,
    'firstName': firstName,
    'lastName': lastName,
    'fullName': fullName,
    'account': account,
    'balance': balance,
    'balanceDebt': balanceDebt,
    'phone': phone,
    'email': email,
    'notes': notes,
    'status': status,
    'company': companyId,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city': city,
    'region': region,
    'country': country,
    'postalCode': postalCode,
    'operation': type,
    'type': type.toUpperCase(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
