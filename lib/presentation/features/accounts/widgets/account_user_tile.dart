// Row tile for account member with context menu, accept/revoke, role change, and optional hard-delete via callback.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/settings/widgets/confirm_panel.dart';

class AccountUserTile extends ConsumerStatefulWidget {
  final AccountUser member;
  final VoidCallback onChanged;
  final Future<void> Function(AccountUser m)? onAccept;
  final VoidCallback? onView;
  final bool canManageRoles;
  final Future<void> Function(AccountUser m)? onDelete;

  const AccountUserTile({
    super.key,
    required this.member,
    required this.onChanged,
    this.onAccept,
    this.onView,
    this.canManageRoles = false,
    this.onDelete,
  });

  @override
  ConsumerState<AccountUserTile> createState() => _AccountUserTileState();
}

class _AccountUserTileState extends ConsumerState<AccountUserTile> {
  bool _busy = false;
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

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

  String _initials(String s) {
    final parts =
        s
            .replaceAll(RegExp(r'[^a-zA-Z0-9@._+\s-]'), ' ')
            .trim()
            .split(RegExp(r'[\s._@-]+'))
          ..removeWhere((e) => e.isEmpty);
    if (parts.isEmpty) return '👤';
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
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

  bool get _canAccept {
    final isPending = (widget.member.status ?? '').toUpperCase() == 'PENDING';
    final isOwnerTarget = (widget.member.role ?? '').toUpperCase() == 'OWNER';
    return isPending && !isOwnerTarget;
  }

  bool get _targetIsOwner =>
      (widget.member.role ?? '').toUpperCase() == 'OWNER';

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

  Future<bool> _confirmRoleChange(String nextRole) async {
    final label = _roleLabelFor(nextRole);
    final ok = await showRightDrawer<bool>(
      context,
      child: ConfirmPanel(
        icon: Icons.manage_accounts,
        title: 'Changer le rôle ?',
        message: 'Définir le rôle sur « $label » pour ce membre ?',
        confirmLabel: 'Changer',
        cancelLabel: 'Annuler',
      ),
      widthFraction: 0.86,
      heightFraction: 0.5,
    );
    return ok == true;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: const ConfirmPanel(
        icon: Icons.delete_outline,
        title: 'Supprimer ce membre ?',
        message:
            'Cette action retirera définitivement ce membre de la liste locale.',
        confirmLabel: 'Supprimer',
        cancelLabel: 'Annuler',
      ),
      widthFraction: 0.86,
      heightFraction: 0.5,
    );
    return ok == true;
  }

  Future<void> _changeRole(String nextRole) async {
    if (_busy) return;
    if (!widget.canManageRoles) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous n’êtes pas autorisé à modifier les rôles.'),
          ),
        );
      }
      return;
    }
    if (_targetIsOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le rôle du propriétaire ne peut pas être modifié.'),
          ),
        );
      }
      return;
    }
    final ok = await _confirmRoleChange(nextRole);
    if (!ok) return;
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

  Future<void> _accept() async {
    if (_busy || !_canAccept) return;
    setState(() => _busy = true);
    try {
      if (widget.onAccept != null) {
        await widget.onAccept!(widget.member);
      } else {
        final repo = ref.read(accountUserRepoProvider);
        await repo.accept(widget.member.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation acceptée.')));
      }
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Échec de l’acceptation')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<void> _delete() async {
    if (_busy || widget.onDelete == null) return;
    if (_targetIsOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le propriétaire ne peut pas être supprimé.'),
          ),
        );
      }
      return;
    }
    final ok = await _confirmDelete(context);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete!(widget.member);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Membre supprimé.')));
      }
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la suppression')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _actionsBar(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final maxW = math.max(180.0, math.min(w * 0.54, 420.0));
    final showRoleChip = w >= 360;
    final cs = Theme.of(context).colorScheme;
    final showRoleChangeItems = widget.canManageRoles && !_targetIsOwner;
    final canDelete = widget.onDelete != null && !_targetIsOwner;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            if (showRoleChip)
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
            if (_canAccept)
              Tooltip(
                message: 'Accepter l’invitation',
                child: FilledButton.icon(
                  onPressed: _accept,
                  icon: const Icon(Icons.check),
                  label: const Text('Accepter'),
                ),
              ),
            if (canDelete)
              Tooltip(
                message: 'Supprimer',
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  label: Text(
                    'Supprimer',
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              key: _menuKey,
              tooltip: 'Actions',
              itemBuilder: (context) => [
                if (showRoleChangeItems)
                  const PopupMenuItem(
                    value: 'viewer',
                    child: Text('Mettre Lecteur'),
                  ),
                if (showRoleChangeItems)
                  const PopupMenuItem(
                    value: 'editor',
                    child: Text('Mettre Éditeur'),
                  ),
                if (showRoleChangeItems || canDelete) const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'revoke',
                  child: Text('Révoquer l’accès'),
                ),
                if (_canAccept)
                  const PopupMenuItem(value: 'accept', child: Text('Accepter')),
                if (canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer'),
                  ),
              ],
              onSelected: (v) async {
                switch (v) {
                  case 'viewer':
                    await _changeRole('VIEWER');
                    break;
                  case 'editor':
                    await _changeRole('EDITOR');
                    break;
                  case 'accept':
                    await _accept();
                    break;
                  case 'revoke':
                    await _revoke();
                    break;
                  case 'delete':
                    await _delete();
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
    final showSubtitle = MediaQuery.sizeOf(context).width >= 380;
    final subtitle = dt != null && showSubtitle
        ? Formatters.dateVeryShort(dt.toLocal())
        : null;
    final identity = _displayIdentity;
    final identityShort = identity.length <= 14
        ? identity
        : '${identity.substring(0, 13)}…';

    print("identity");
    print(identity);

    return Semantics(
      label: 'Membre $identity',
      button: false,
      child: InkWell(
        onTap: widget.onView,
        onLongPress: () {
          HapticFeedback.selectionClick();
          _menuKey.currentState?.showButtonMenu();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      child: Text(
                        identity.isEmpty ? '👤' : _initials(identity),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      identityShort,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
                Expanded(child: _actionsBar(context)),
            ],
          ),
        ),
      ),
    );
  }
}
