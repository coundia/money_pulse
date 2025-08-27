/* Reusable tile for an account member with role/status chips and context menu. */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AccountUserTile extends ConsumerWidget {
  final AccountUser member;
  final VoidCallback onChanged;
  const AccountUserTile({
    super.key,
    required this.member,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleLabel = member.role == 'OWNER'
        ? 'Propriétaire'
        : member.role == 'EDITOR'
        ? 'Éditeur'
        : 'Lecteur';
    final statusLabel = member.status == 'ACCEPTED'
        ? 'Accepté'
        : member.status == 'PENDING'
        ? 'En attente'
        : 'Révoqué';
    return ListTile(
      title: Text(member.user ?? member.email ?? member.phone ?? 'Membre'),
      subtitle: Text(
        [
          if (member.updatedAt != null)
            'MAJ: ${Formatters.dateFull(member.updatedAt!.toLocal())}',
        ].join(' • '),
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Chip(label: Text(roleLabel)),
          Chip(label: Text(statusLabel)),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) async {
              final repo = ref.read(accountUserRepoProvider);
              if (v == 'viewer') await repo.updateRole(member.id, 'VIEWER');
              if (v == 'editor') await repo.updateRole(member.id, 'EDITOR');
              if (v == 'revoke') await repo.revoke(member.id);
              onChanged();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'viewer', child: Text('Mettre Lecteur')),
              PopupMenuItem(value: 'editor', child: Text('Mettre Éditeur')),
              PopupMenuItem(value: 'revoke', child: Text('Révoquer l’accès')),
            ],
          ),
        ],
      ),
    );
  }
}
