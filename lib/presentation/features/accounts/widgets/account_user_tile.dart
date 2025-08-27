/* Reusable row tile for an account member with identity caption, compact chips, wrapped action bar to avoid horizontal overflow, and drawer confirmation. */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/settings/widgets/confirm_panel.dart';

class AccountUserTile extends ConsumerStatefulWidget {
  final AccountUser member;
  final VoidCallback onChanged;
  const AccountUserTile({
    super.key,
    required this.member,
    required this.onChanged,
  });

  @override
  ConsumerState<AccountUserTile> createState() => _AccountUserTileState();
}

class _AccountUserTileState extends ConsumerState<AccountUserTile> {
  bool _busy = false;

  String get _displayIdentity {
    final m = widget.member;
    return m.identity?.trim().isNotEmpty == true
        ? m.identity!.trim()
        : (m.user?.trim().isNotEmpty == true
              ? m.user!.trim()
              : (m.email?.trim().isNotEmpty == true
                    ? m.email!.trim()
                    : (m.phone?.trim().isNotEmpty == true
                          ? m.phone!.trim()
                          : 'Membre')));
  }

  String get _identityShort {
    final s = _displayIdentity;
    const maxLen = 14;
    return s.length <= maxLen ? s : '${s.substring(0, maxLen - 1)}…';
  }

  String get _roleLabel {
    switch (widget.member.role) {
      case 'OWNER':
        return 'Propriétaire';
      case 'EDITOR':
        return 'Éditeur';
      default:
        return 'Lecteur';
    }
  }

  IconData get _roleIcon {
    switch (widget.member.role) {
      case 'OWNER':
        return Icons.verified_user;
      case 'EDITOR':
        return Icons.edit;
      default:
        return Icons.remove_red_eye;
    }
  }

  String get _statusLabel {
    switch (widget.member.status) {
      case 'ACCEPTED':
        return 'Accepté';
      case 'PENDING':
        return 'En attente';
      default:
        return 'Révoqué';
    }
  }

  IconData get _statusIcon {
    switch (widget.member.status) {
      case 'ACCEPTED':
        return Icons.check_circle;
      case 'PENDING':
        return Icons.hourglass_bottom;
      default:
        return Icons.block;
    }
  }

  DateTime? get _updatedAtLike =>
      widget.member.updatedAt ??
      widget.member.createdAt ??
      widget.member.invitedAt;

  Future<bool> _confirmRevoke(BuildContext context) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: const ConfirmPanel(
        icon: Icons.block,
        title: 'Révoquer l’accès ?',
        message: 'Le membre ne pourra plus accéder à ce compte. Continuer ?',
        confirmLabel: 'Révoquer',
        cancelLabel: 'Annuler',
      ),
      widthFraction: 0.86,
      heightFraction: 0.5,
    );
    return ok == true;
  }

  Future<void> _changeRole(String nextRole) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(accountUserRepoProvider);
      await repo.updateRole(widget.member.id, nextRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rôle mis à jour : ${_roleLabelFor(nextRole)}'),
          ),
        );
      }
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de mise à jour du rôle')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleLabelFor(String r) {
    switch (r) {
      case 'OWNER':
        return 'Propriétaire';
      case 'EDITOR':
        return 'Éditeur';
      default:
        return 'Lecteur';
    }
  }

  Future<void> _revoke() async {
    if (_busy) return;
    final ok = await _confirmRevoke(context);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(accountUserRepoProvider);
      await repo.revoke(widget.member.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Accès révoqué.')));
      }
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Échec de la révocation')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _actionsBar() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Tooltip(
              message: 'Rôle : $_roleLabel',
              child: InputChip(
                isEnabled: false,
                avatar: Icon(_roleIcon, size: 16),
                label: Text(_roleLabel),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Tooltip(
              message: 'Statut : $_statusLabel',
              child: InputChip(
                isEnabled: false,
                avatar: Icon(_statusIcon, size: 16),
                label: Text(_statusLabel),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'viewer', child: Text('Mettre Lecteur')),
                PopupMenuItem(value: 'editor', child: Text('Mettre Éditeur')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'revoke', child: Text('Révoquer l’accès')),
              ],
              onSelected: (v) async {
                switch (v) {
                  case 'viewer':
                    await _changeRole('VIEWER');
                    break;
                  case 'editor':
                    await _changeRole('EDITOR');
                    break;
                  case 'revoke':
                    await _revoke();
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dt = _updatedAtLike;
    final subtitle = dt != null ? Formatters.dateShort(dt.toLocal()) : '';

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Text(
                      _displayIdentity.isEmpty
                          ? '👤'
                          : _displayIdentity
                                .replaceAll(RegExp(r'[^a-zA-Z0-9@._+\s-]'), ' ')
                                .trim()
                                .split(RegExp(r'[\s._@-]+'))
                                .where((e) => e.isNotEmpty)
                                .take(2)
                                .map((e) => e[0].toUpperCase())
                                .join(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _identityShort,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Flexible(child: _actionsBar()),
          ],
        ),
      ),
    );
  }
}
