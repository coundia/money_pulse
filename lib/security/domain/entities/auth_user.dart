/// Domain entity representing the authenticated user profile.
import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final List<String> roles;
  final List<String> permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AuthUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.roles = const [],
    this.permissions = const [],
    this.createdAt,
    this.updatedAt,
  });

  AuthUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    List<String>? roles,
    List<String>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'roles': roles,
      'permissions': permissions,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: (json['id'] ?? '') as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      roles:
          (json['roles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      permissions:
          (json['permissions'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    avatarUrl,
    roles,
    permissions,
    createdAt,
    updatedAt,
  ];
}
