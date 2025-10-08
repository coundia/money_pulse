// Right-drawer to request access code using only phone number (WhatsApp-based login).
// Simplified and mobile-first design for single-step identity entry.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/features/access/panels/access_register_panel.dart';
import '../providers/access_repo_provider.dart';
import '../../domain/models/access_identity.dart';
import 'package:money_pulse/presentation/app/installation_id_provider.dart';
import 'access_password_login_panel.dart';
import '../../domain/entities/access_grant.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'access_code_verify_panel.dart';

class AccessEmailRequestResult {
  final AccessIdentity identity;
  const AccessEmailRequestResult(this.identity);
}

class AccessEmailRequestPanel extends ConsumerStatefulWidget {
  final String? initialPhone;
  const AccessEmailRequestPanel({super.key, this.initialPhone});

  @override
  ConsumerState<AccessEmailRequestPanel> createState() =>
      _AccessEmailRequestPanelState();
}

class _AccessEmailRequestPanelState
    extends ConsumerState<AccessEmailRequestPanel> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.initialPhone ?? '';
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool get _phoneValid {
    final v = _phoneCtrl.text.trim();
    return RegExp(r'^[0-9+\-\s]{6,20}$').hasMatch(v);
  }

  Future<AccessIdentity> _buildIdentity() async {
    final phone = _phoneCtrl.text.trim();
    final source = await ref.read(installationIdProvider.future);
    return AccessIdentity(
      username: phone,
      phone: phone,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      notes: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      source: source,
    );
  }

  Future<void> _submit() async {
    if (_sending || !_phoneValid) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _sending = true);
    try {
      final identity = await _buildIdentity();
      final uc = ref.read(requestAccessUseCaseProvider);
      await uc.execute(identity);
      if (!mounted) return;

      final grant = await showRightDrawer<AccessGrant?>(
        context,
        child: AccessCodeVerifyPanel(identity: identity),
      );
      if (grant != null) {
        Navigator.of(context).pop<AccessGrant>(grant);
      } else {
        Navigator.of(context).pop(AccessEmailRequestResult(identity));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l’envoi du code. Vérifiez votre numéro.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openPasswordLogin() async {
    final grant = await showRightDrawer<AccessGrant?>(
      context,
      child: const AccessPasswordLoginPanel(),
    );
    if (grant != null && mounted) Navigator.of(context).pop(grant);
  }

  Future<void> _openRegister() async {
    final username = await showRightDrawer<String?>(
      context,
      child: AccessRegisterPanel(
        initialUsername: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
      ),
    );
    if (username != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compte créé. Demandez un code pour valider votre numéro.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = {
      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Demande d’accès'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 720;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Entrez votre numéro WhatsApp pour recevoir un code de connexion.',
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            _phoneField(),
                            const SizedBox(height: 12),
                            _nameField(),
                            const SizedBox(height: 12),
                            _messageField(),
                            const SizedBox(height: 24),
                            _buttonsLayout(isWide),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneField() => TextFormField(
    controller: _phoneCtrl,
    focusNode: _phoneFocus,
    decoration: InputDecoration(
      labelText: 'Numéro de téléphone (WhatsApp)',
      hintText: '221 77 000 00 00',
      prefixIcon: const Icon(Icons.phone),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      errorText: _phoneCtrl.text.isEmpty
          ? null
          : (_phoneValid ? null : 'Numéro invalide'),
    ),
    keyboardType: TextInputType.phone,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))],
    textInputAction: TextInputAction.next,
    onFieldSubmitted: (_) => _submit(),
    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
  );

  Widget _nameField() => TextFormField(
    controller: _nameCtrl,
    decoration: InputDecoration(
      labelText: 'Nom complet',
      hintText: 'Prénom Nom',
      prefixIcon: const Icon(Icons.person_outline),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textInputAction: TextInputAction.next,
    onFieldSubmitted: (_) => _submit(),
  );

  Widget _messageField() => TextFormField(
    controller: _messageCtrl,
    decoration: InputDecoration(
      labelText: 'Message (optionnel)',
      prefixIcon: const Icon(Icons.message_outlined),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    minLines: 2,
    maxLines: 4,
    textInputAction: TextInputAction.done,
  );

  Widget _buttonsLayout(bool isWide) {
    final children = [
      SizedBox(
        width: isWide ? 220 : double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Recevoir le code'),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _openPasswordLogin,
        icon: const Icon(Icons.lock_open),
        label: const Text('Connexion avec mot de passe'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _openRegister,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Créer un compte'),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _openPasswordLogin,
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('J’ai déjà reçu le code'),
      ),
    ];
    return isWide
        ? Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: children,
          )
        : Column(children: children);
  }
}
