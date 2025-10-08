// Right-drawer to request an access code using phone only, with non-intrusive bottom warning instead of red error text.
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
  bool _dirtyPhone = false;

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
    return RegExp(r'^[0-9]{2,30}$').hasMatch(v);
  }

  String? get _warningText {
    if (!_dirtyPhone) return null;
    if (_phoneCtrl.text.trim().isEmpty) {
      return 'Veuillez saisir votre numéro de téléphone.';
    }
    if (!_phoneValid) {
      return 'Veuillez saisir un bon numéro de téléphone.';
    }
    return null;
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
    _dirtyPhone = true;
    setState(() {});
    if (_sending || !_phoneValid) {
      _phoneFocus.requestFocus();
      return;
    }

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
                      autovalidateMode: AutovalidateMode.disabled,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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
                                _buttonsRow(isWide),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              child: _bottomWarningBar(),
                            ),
                          ),
                        ],
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
    decoration: const InputDecoration(
      labelText: 'Numéro de téléphone (WhatsApp)',
      hintText: '770000000',
      prefixIcon: Icon(Icons.phone),
      counterText: '',
    ),
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(15),
    ],
    maxLength: 15,
    textInputAction: TextInputAction.done,
    onChanged: (_) {
      _dirtyPhone = true;
      setState(() {});
    },
    onFieldSubmitted: (_) => _submit(),
  );

  Widget _nameField() => TextFormField(
    controller: _nameCtrl,
    decoration: const InputDecoration(
      labelText: 'Nom complet',
      hintText: 'Prénom Nom',
      prefixIcon: Icon(Icons.person_outline),
    ),
    textInputAction: TextInputAction.next,
    onFieldSubmitted: (_) => _submit(),
  );

  Widget _messageField() => TextFormField(
    controller: _messageCtrl,
    decoration: const InputDecoration(
      labelText: 'Message (optionnel)',
      prefixIcon: Icon(Icons.message_outlined),
    ),
    minLines: 2,
    maxLines: 4,
    textInputAction: TextInputAction.done,
  );

  Widget _buttonsRow(bool isWide) {
    final children = [
      Expanded(
        child: SizedBox(
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
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: _openPasswordLogin,
        icon: const Icon(Icons.lock_open),
        label: const Text('Mot de passe'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: _openRegister,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Créer un compte'),
      ),
    ];

    return isWide
        ? Row(children: children)
        : Column(
            children: [
              SizedBox(
                width: double.infinity,
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _openPasswordLogin,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Mot de passe'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _openRegister,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Créer un compte'),
                ),
              ),
            ],
          );
  }

  Widget _bottomWarningBar() {
    final text = _warningText;
    final show = text != null;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      offset: show ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: show ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(14),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text ?? '',
                      style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!_phoneValid)
                    TextButton(
                      onPressed: () => _phoneFocus.requestFocus(),
                      child: const Text('Corriger'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
