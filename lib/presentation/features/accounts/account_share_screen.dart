/* Full-screen page to invite and manage account sharing with search and enter-to-submit. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_list_providers.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_user_tile.dart';

class AccountShareScreen extends ConsumerStatefulWidget {
  final String accountId;
  final String? accountName;
  const AccountShareScreen({
    super.key,
    required this.accountId,
    this.accountName,
  });

  @override
  ConsumerState<AccountShareScreen> createState() => _AccountShareScreenState();
}

class _AccountShareScreenState extends ConsumerState<AccountShareScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _role = 'VIEWER';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[ShareScreen] init accountId=${widget.accountId} title=${widget.accountName}',
    );
    //_searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(accountUserRepoProvider);
      final now = DateTime.now().toUtc();
      final au = AccountUser(
        id: const Uuid().v4(),
        account: widget.accountId,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        role: _role,
        status: 'PENDING',
        invitedBy: 'me',
        invitedAt: now,
        createdAt: now,
        updatedAt: now,
        isDirty: 1,
      );
      await repo.invite(au);
      _emailCtrl.clear();
      _phoneCtrl.clear();
      ref.invalidate(accountUserListProvider(widget.accountId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation envoyée')));
      }
    } catch (e, st) {
      debugPrint('[ShareScreen] ERROR invite: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l’invitation')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _applySearch(String v) {
    ref.read(accountUserSearchProvider.notifier).state = v.trim();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(accountUserListProvider(widget.accountId));
    final title = widget.accountName == null
        ? 'Partager le compte'
        : 'Partager: ${widget.accountName}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ajoutez des personnes par email ou téléphone, puis définissez le rôle.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  },
                  child: Actions(
                    actions: {
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (e) => _invite(),
                      ),
                    },
                    child: Focus(
                      autofocus: true,
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final isWide = c.maxWidth > 560;
                          final emailField = Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email du membre',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _invite(),
                              validator: (_) {
                                if (_emailCtrl.text.trim().isEmpty &&
                                    _phoneCtrl.text.trim().isEmpty) {
                                  return 'Renseignez email ou téléphone';
                                }
                                return null;
                              },
                            ),
                          );
                          final phoneField = Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone du membre',
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _invite(),
                            ),
                          );
                          final roleField = DropdownButton<String>(
                            value: _role,
                            onChanged: (v) => setState(() => _role = v!),
                            items: const [
                              DropdownMenuItem(
                                value: 'VIEWER',
                                child: Text('Lecteur'),
                              ),
                              DropdownMenuItem(
                                value: 'EDITOR',
                                child: Text('Éditeur'),
                              ),
                              DropdownMenuItem(
                                value: 'OWNER',
                                child: Text('Propriétaire'),
                              ),
                            ],
                          );
                          final inviteBtn = FilledButton.icon(
                            onPressed: _sending ? null : _invite,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Inviter'),
                          );

                          if (isWide) {
                            return Row(
                              children: [
                                emailField,
                                const SizedBox(width: 12),
                                phoneField,
                                const SizedBox(width: 12),
                                roleField,
                                const SizedBox(width: 12),
                                inviteBtn,
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              emailField,
                              const SizedBox(height: 8),
                              phoneField,
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  roleField,
                                  const SizedBox(width: 8),
                                  inviteBtn,
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        labelText: 'Rechercher un membre',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applySearch('');
                                },
                                icon: const Icon(Icons.clear),
                                tooltip: 'Effacer',
                              ),
                      ),
                      onChanged: _applySearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final link = 'money-pulse://share/${widget.accountId}';
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lien copié')),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Copier le lien'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Membres',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: listAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) {
                    debugPrint('[ShareScreen] ERROR list: $e');
                    debugPrintStack(stackTrace: st);
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Erreur de chargement'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => ref.invalidate(
                              accountUserListProvider(widget.accountId),
                            ),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    );
                  },
                  data: (members) {
                    if (members.isEmpty) {
                      return const Center(child: Text('Aucun membre'));
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          accountUserListProvider(widget.accountId),
                        );
                        await Future.delayed(const Duration(milliseconds: 200));
                      },
                      child: ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          return AccountUserTile(
                            member: members[i],
                            onChanged: () => ref.invalidate(
                              accountUserListProvider(widget.accountId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Conseil: donnez le rôle “Lecteur” pour un simple suivi, “Éditeur” pour ajouter des opérations.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> openAccountShareScreen<T>(
  BuildContext context, {
  required String accountId,
  String? accountName,
}) {
  debugPrint('[ShareScreen] open route');
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          AccountShareScreen(accountId: accountId, accountName: accountName),
    ),
  );
}
