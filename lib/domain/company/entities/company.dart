import 'package:equatable/equatable.dart';

class Company extends Equatable {
  final String id;
  final String? remoteId;
  final String code;
  final String name;
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
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;

  const Company({
    required this.id,
    this.remoteId,
    required this.code,
    required this.name,
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
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = true,
  });

  Company copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? name,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? taxId,
    String? currency,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? region,
    String? country,
    String? postalCode,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return Company(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      currency: currency ?? this.currency,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      region: region ?? this.region,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
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

  factory Company.fromMap(Map<String, Object?> m) => Company(
    id: m['id'] as String,
    remoteId: m['remoteId'] as String?,
    code: (m['code'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    description: m['description'] as String?,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    website: m['website'] as String?,
    taxId: m['taxId'] as String?,
    currency: m['currency'] as String?,
    addressLine1: m['addressLine1'] as String?,
    addressLine2: m['addressLine2'] as String?,
    city: m['city'] as String?,
    region: m['region'] as String?,
    country: m['country'] as String?,
    postalCode: m['postalCode'] as String?,
    isDefault: _i(m['isDefault']) == 1,
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
    'isDefault': isDefault ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'syncAt': syncAt?.toIso8601String(),
    'version': version,
    'isDirty': isDirty ? 1 : 0,
  };

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    phone,
    email,
    website,
    isDefault,
    updatedAt,
    deletedAt,
    version,
    isDirty,
  ];
}
