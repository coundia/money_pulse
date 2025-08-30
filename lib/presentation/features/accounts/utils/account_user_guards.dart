/* Helpers for membership permissions: normalize phone and determine if the connected user is the inviter/creator of a member. */
import 'package:money_pulse/domain/accounts/entities/account_user.dart';

class AccountUserGuards {
  static String? normalizePhone(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    final digitsPlus = v.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsPlus.startsWith('00')) return '+${digitsPlus.substring(2)}';
    if (!digitsPlus.startsWith('+') && digitsPlus.isNotEmpty)
      return '+$digitsPlus';
    return digitsPlus;
  }

  static bool isCreator({
    required AccountUser member,
    String? connectedUsername,
    String? connectedPhone,
  }) {
    final creatorRaw = (member.invitedBy?.trim().isNotEmpty == true)
        ? member.invitedBy!.trim()
        : member.createdBy?.trim();

    final creatorUser = creatorRaw?.toLowerCase();
    final creatorPhone = normalizePhone(creatorRaw);

    final userOk =
        creatorUser != null &&
        connectedUsername != null &&
        creatorUser == connectedUsername.toLowerCase();

    final phoneOk =
        creatorPhone != null &&
        normalizePhone(connectedPhone) != null &&
        creatorPhone == normalizePhone(connectedPhone);

    return userOk || phoneOk;
  }

  static bool canManageMember({
    required AccountUser member,
    required bool canManageRolesFlag,
    String? connectedUsername,
    String? connectedPhone,
  }) {
    return canManageRolesFlag ||
        isCreator(
          member: member,
          connectedUsername: connectedUsername,
          connectedPhone: connectedPhone,
        );
  }

  static bool canHardDelete({
    required AccountUser member,
    required bool canManageRolesFlag,
    String? connectedUsername,
    String? connectedPhone,
  }) {
    return canManageMember(
      member: member,
      canManageRolesFlag: canManageRolesFlag,
      connectedUsername: connectedUsername,
      connectedPhone: connectedPhone,
    );
  }
}
