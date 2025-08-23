// Right-drawer form to choose email or phone as identity, then request a code; Enter submits; responsive and accessible.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/access_repo_provider.dart';
import '../../domain/models/access_identity.dart';

class AccessEmailRequestResult {
  final AccessIdentity identity;
  const AccessEmailRequestResult(this.identity);
}

enum IdentityMode { email, phone }

class AccessEmailRequestPanel extends ConsumerStatefulWidget {
  final String? initialEmail;
  const AccessEmailRequestPanel({super.key, this.initialEmail});

  @override
  ConsumerState<AccessEmailRequestPanel> createState() =>
      _AccessEmailRequestPanelState();
}

class _AccessEmailRequestPanelState
    extends ConsumerState<AccessEmailRequestPanel> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  IdentityMode _mode = IdentityMode.phone;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
  }

  bool get _phoneValid {
    final v = _phoneCtrl.text.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[0-9+\-\s]{6,20}$').hasMatch(v);
  }

  bool get _identityValid =>
      _mode == IdentityMode.email ? _emailValid : _phoneValid;

  String get _username => _mode == IdentityMode.email
      ? _emailCtrl.text.trim()
      : _phoneCtrl.text.trim();

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok || !_identityValid || _sending) return;

    setState(() => _sending = true);
    try {
      final email = _mode == IdentityMode.email ? _emailCtrl.text.trim() : '';
      final phone = _mode == IdentityMode.phone ? _phoneCtrl.text.trim() : '';
      final identity = AccessIdentity(
        username: _username,
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        notes: _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
      );

      final uc = ref.read(requestAccessUseCaseProvider);
      await uc.execute(identity);
      if (!mounted) return;
      Navigator.of(context).pop(AccessEmailRequestResult(identity));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l’envoi du code. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter):
          const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
          const ActivateIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
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
                return Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Choisissez votre méthode et saisissez votre contact pour recevoir un code de confirmation.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            _modeSwitcher(),
                            const SizedBox(height: 12),
                            if (isWide)
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _identityField()),
                                      const SizedBox(width: 12),
                                      Expanded(child: _nameField()),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _messageField(),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Les autres champs sont optionnels.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: 220,
                                    height: 48,
                                    child: _primaryBtn(),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Text("Champs Obligatoire"),
                                  const SizedBox(height: 12),
                                  _identityField(),
                                  const SizedBox(height: 12),
                                  Text("Champs optionnels"),
                                  const SizedBox(height: 12),
                                  _nameField(),
                                  const SizedBox(height: 12),
                                  _messageField(),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Les autres champs sont optionnels.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: _primaryBtn(),
                                  ),
                                ],
                              ),
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

  Widget _modeSwitcher() {
    return SegmentedButton<IdentityMode>(
      segments: const [
        ButtonSegment(
          value: IdentityMode.phone,
          label: Text('Téléphone (WhatsApp)'),
          icon: Icon(Icons.phone),
        ),
        ButtonSegment(
          value: IdentityMode.email,
          label: Text('E-mail'),
          icon: Icon(Icons.alternate_email),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (s) {
        setState(() => _mode = s.first);
        Future.microtask(() {
          if (_mode == IdentityMode.email) {
            _emailFocus.requestFocus();
          } else {
            _phoneFocus.requestFocus();
          }
        });
      },
    );
  }

  Widget _identityField() {
    if (_mode == IdentityMode.email) {
      return TextFormField(
        controller: _emailCtrl,
        focusNode: _emailFocus,
        decoration: InputDecoration(
          labelText: 'Adresse e-mail',
          hintText: 'exemple@domaine.com',
          prefixIcon: const Icon(Icons.alternate_email),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          errorText: _emailCtrl.text.isEmpty
              ? null
              : (_emailValid ? null : 'E-mail invalide'),
        ),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _submit(),
      );
    }
    return TextFormField(
      controller: _phoneCtrl,
      focusNode: _phoneFocus,
      decoration: InputDecoration(
        labelText: 'Téléphone',
        hintText: '221 77 000 00 00',
        prefixIcon: const Icon(Icons.phone_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _phoneCtrl.text.isEmpty
            ? null
            : (_phoneValid ? null : 'Numéro invalide'),
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
      ],
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: _nameCtrl,
      decoration: InputDecoration(
        labelText: 'Nom complet',
        hintText: 'Prénom Nom',
        prefixIcon: const Icon(Icons.badge_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _messageField() {
    return TextFormField(
      controller: _messageCtrl,
      decoration: InputDecoration(
        labelText: 'Message',
        hintText: 'Votre message (optionnel)',
        prefixIcon: const Icon(Icons.message_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      minLines: 2,
      maxLines: 4,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _primaryBtn() {
    final canSubmit = !_sending;
    return ElevatedButton.icon(
      onPressed: canSubmit ? _submit : null,
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send),
      label: const Text('Recevoir le code'),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
