// Full-screen page to invite and manage account sharing with identity auto-detect, enter-to-submit, duplicate guard, preview with accept and delete actions, and right-drawer to view more.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_list_providers.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_user_tile.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/accounts/panels/account_user_list_panel.dart';
import 'package:money_pulse/presentation/app/connected_username_provider.dart';

class AccountShareScreen extends ConsumerStatefulWidget {
  final String accountId;
  final String? accountName;
  final bool canManageRoles;

  const AccountShareScreen({
    super.key,
    required this.accountId,
    this.accountName,
    this.canManageRoles = true,
  });

  @override
  ConsumerState<AccountShareScreen> createState() => _AccountShareScreenState();
}

class _AccountShareScreenState extends ConsumerState<AccountShareScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _identFocus = FocusNode();
  final _messageFocus = FocusNode();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _identFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _identCtrl.dispose();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _identFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  bool _isEmail(String v) => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
  bool _isPhone(String v) => RegExp(r'^[0-9 +()-]{6,}$').hasMatch(v.trim());

  bool get _identValid {
    final v = _identCtrl.text.trim();
    if (v.isEmpty) return false;
    if (_isEmail(v)) return true;
    if (_isPhone(v)) return true;
    return v.length >= 2;
  }

  DateTime _sortKey(AccountUser m) {
    return (m.updatedAt ??
            m.createdAt ??
            m.invitedAt ??
            DateTime.fromMillisecondsSinceEpoch(0))
        .toUtc();
  }

  Future<void> _pasteIntoIdent() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    _identCtrl.text = text;
    setState(() {});
  }

  Future<void> _acceptMember(AccountUser m) async {
    try {
      final repo = ref.read(accountUserRepoProvider);
      await repo.accept(m.id);
      ref.invalidate(accountUserListProvider(widget.accountId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation acceptée')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Échec de l’acceptation')));
      }
    }
  }

  Future<bool> _existsDuplicate(
    String ident, {
    String? email,
    String? phone,
  }) async {
    try {
      final repo = ref.read(accountUserRepoProvider);
      final list = await repo.listByAccount(widget.accountId, q: ident);
      bool same(AccountUser x) {
        final i = (x.identity ?? '').trim().toLowerCase();
        final e = (x.email ?? '').trim().toLowerCase();
        final p = (x.phone ?? '').trim();
        final identL = ident.trim().toLowerCase();
        return i == identL || e == identL || p == phone?.trim();
      }

      return list.any(same);
    } catch (_) {
      return false;
    }
  }

  Future<void> _invite() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_identValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Identifiant invalide.')));
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(accountUserRepoProvider);
      final now = DateTime.now().toUtc();

      final ident = _identCtrl.text.trim();
      String? email;
      String? phone;
      if (_isEmail(ident)) {
        email = ident;
      } else if (_isPhone(ident)) {
        phone = ident;
      }

      if (await _existsDuplicate(ident, email: email, phone: phone)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cet identifiant existe déjà.')),
          );
        }
        return;
      }

      final inviterUsername = ref.read(connectedUsernameProvider);
      final inviterPhone = ref.read(connectedPhoneProvider);
      final createdBy = (inviterUsername?.trim().isNotEmpty == true)
          ? inviterUsername!.trim().toLowerCase()
          : (inviterPhone?.trim().isNotEmpty == true
                ? _normalizePhone(inviterPhone)
                : null);

      final au = AccountUser(
        id: const Uuid().v4(),
        account: widget.accountId,
        identity: ident,
        email: email,
        phone: phone,
        role: 'VIEWER',
        status: 'PENDING',
        invitedBy: createdBy ?? 'me',
        createdBy: createdBy,
        invitedAt: now,
        createdAt: now,
        updatedAt: now,
        message: _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
        isDirty: 1,
      );

      await repo.invite(au);
      _identCtrl.clear();
      _messageCtrl.clear();
      ref.invalidate(accountUserListProvider(widget.accountId));
      _identFocus.requestFocus();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation envoyée')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l’invitation')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _normalizePhone(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    final digitsPlus = v.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsPlus.startsWith('00')) return '+${digitsPlus.substring(2)}';
    if (!digitsPlus.startsWith('+') && digitsPlus.isNotEmpty)
      return '+$digitsPlus';
    return digitsPlus;
  }

  Future<void> _openMembersPanel() async {
    await showRightDrawer(
      context,
      child: AccountUserListPanel(
        accountId: widget.accountId,
        accountName: widget.accountName,
        canManageRoles: widget.canManageRoles,
      ),
      widthFraction: 0.86,
      heightFraction: 1.0,
    );
  }

  Widget _identField() {
    return TextFormField(
      controller: _identCtrl,
      focusNode: _identFocus,
      decoration: InputDecoration(
        labelText: 'Identifiant',
        hintText: 'E-mail, login ou téléphone',
        prefixIcon: const Icon(Icons.person_outline),
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Options',
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'paste', child: Text('Coller')),
            PopupMenuItem(value: 'clear', child: Text('Effacer')),
          ],
          onSelected: (v) async {
            if (v == 'paste') await _pasteIntoIdent();
            if (v == 'clear') {
              _identCtrl.clear();
              setState(() {});
              _identFocus.requestFocus();
            }
          },
        ),
        helperText: 'Exemples : email@domaine.sn ou +221 77 123 45 67',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) => _invite(),
      validator: (_) => _identValid ? null : 'Identifiant invalide',
    );
  }

  Widget _messageField() {
    return TextFormField(
      controller: _messageCtrl,
      focusNode: _messageFocus,
      decoration: const InputDecoration(
        labelText: 'Message',
        hintText: 'Message optionnel pour le destinataire',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      minLines: 2,
      maxLines: 3,
      maxLength: 200,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _invite(),
    );
  }

  Widget _membersPreview(AsyncValue<List<AccountUser>> listAsync) {
    final username = ref.watch(connectedUsernameProvider);
    final phone = ref.watch(connectedPhoneProvider);
    final usernameL = username?.toLowerCase();
    final phoneN = _normalizePhone(phone);

    return listAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => OutlinedButton.icon(
        onPressed: _openMembersPanel,
        icon: const Icon(Icons.group),
        label: const Text('Voir les membres'),
      ),
      data: (members) {
        final total = members.length;
        if (total == 0) {
          return OutlinedButton.icon(
            onPressed: _openMembersPanel,
            icon: const Icon(Icons.group_add),
            label: const Text('Inviter des membres'),
          );
        }
        final sorted = [...members]
          ..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
        final preview = sorted.take(2).toList();

        bool isCreator(AccountUser m) {
          final createdBy = m.invitedBy?.trim();
          final createdByPhone = _normalizePhone(createdBy);
          final createdByUser = createdBy?.toLowerCase();

          final userOk =
              createdByUser != null &&
              usernameL != null &&
              createdByUser == usernameL;
          final phoneOk =
              createdByPhone != null &&
              phoneN != null &&
              createdByPhone == phoneN;
          return userOk || phoneOk;
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Membres (aperçu)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openMembersPanel,
                      child: Text('Voir plus ($total)'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...preview.map((m) {
                  final canManageThisMember =
                      widget.canManageRoles || isCreator(m);
                  final canHardDelete = true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AccountUserTile(
                      member: m,
                      onChanged: () => ref.invalidate(
                        accountUserListProvider(widget.accountId),
                      ),
                      onAccept: _acceptMember,
                      onView: _openMembersPanel,
                      canManageRoles: canManageThisMember,
                      onDelete: canHardDelete
                          ? (u) async {
                              final repo = ref.read(accountUserRepoProvider);
                              await repo.delete(u.id);
                              ref.invalidate(
                                accountUserListProvider(widget.accountId),
                              );
                            }
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(accountUserListProvider(widget.accountId));
    final title = widget.accountName == null
        ? 'Partager le compte'
        : 'Partager : ${widget.accountName}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
        bottom: _sending
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth > 680;
            return Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter):
                    ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter, control: true):
                    ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter, meta: true):
                    ActivateIntent(),
              },
              child: Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (e) {
                      _invite();
                      return null;
                    },
                  ),
                },
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (isWide)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: _identField()),
                                          const SizedBox(width: 12),
                                          Expanded(child: _messageField()),
                                        ],
                                      )
                                    else ...[
                                      _identField(),
                                      const SizedBox(height: 8),
                                      _messageField(),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: (_sending || !_identValid)
                                            ? null
                                            : _invite,
                                        icon: _sending
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.person_add_alt_1,
                                              ),
                                        label: const Text('Inviter'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _membersPreview(listAsync),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<T?> openAccountShareScreen<T>(
  BuildContext context, {
  required String accountId,
  String? accountName,
  bool canManageRoles = false,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AccountShareScreen(
        accountId: accountId,
        accountName: accountName,
        canManageRoles: canManageRoles,
      ),
    ),
  );
}
