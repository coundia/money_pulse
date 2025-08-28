// Customer entity with balances (amounts in cents) and mapping helpers.
import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String? remoteId;
  final String? code;
  final String? firstName;
  final String? lastName;
  final String fullName;
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
  final String? localId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;
  final String? account;

  const Customer({
    required this.id,
    this.remoteId,
    this.code,
    this.firstName,
    this.lastName,
    required this.fullName,
    this.balance = 0,
    this.balanceDebt = 0,
    this.phone,
    this.email,
    this.notes,
    this.status,
    this.companyId,
    this.addressLine1,
    this.addressLine2,
    this.account,
    this.city,
    this.region,
    this.country,
    this.postalCode,
    this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = true,
  });

  Customer copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? firstName,
    String? lastName,
    String? fullName,
    int? balance,
    int? balanceDebt,
    String? phone,
    String? email,
    String? notes,
    String? status,
    String? companyId,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? region,
    String? country,
    String? postalCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return Customer(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      balance: balance ?? this.balance,
      balanceDebt: balanceDebt ?? this.balanceDebt,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      companyId: companyId ?? this.companyId,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      region: region ?? this.region,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  static int _i(Object? v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
  static DateTime? _dt(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
    id: m['id'] as String,
    remoteId: m['remoteId'] as String?,
    code: m['code'] as String?,
    firstName: m['firstName'] as String?,
    lastName: m['lastName'] as String?,
    fullName:
        (m['fullName'] as String?) ??
        _joinName(m['firstName'] as String?, m['lastName'] as String?),
    balance: _i(m['balance']),
    balanceDebt: _i(m['balanceDebt']),
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    notes: m['notes'] as String?,
    status: m['status'] as String?,
    companyId: m['companyId'] as String?,
    addressLine1: m['addressLine1'] as String?,
    addressLine2: m['addressLine2'] as String?,
    city: m['city'] as String?,
    region: m['region'] as String?,
    country: m['country'] as String?,
    postalCode: m['postalCode'] as String?,
    createdAt: _dt(m['createdAt']) ?? DateTime.now(),
    updatedAt: _dt(m['updatedAt']) ?? DateTime.now(),
    deletedAt: _dt(m['deletedAt']),
    syncAt: _dt(m['syncAt']),
    version: _i(m['version']),
    isDirty: _i(m['isDirty']) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
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
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'syncAt': syncAt?.toIso8601String(),
    'version': version,
    'isDirty': isDirty ? 1 : 0,
  };

  static String _joinName(String? first, String? last) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    return [f, l].where((e) => e.isNotEmpty).join(' ').trim();
  }

  @override
  List<Object?> get props => [
    id,
    fullName,
    balance,
    balanceDebt,
    phone,
    email,
    companyId,
    updatedAt,
    deletedAt,
    version,
    isDirty,
  ];
}
