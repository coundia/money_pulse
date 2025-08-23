// Right-drawer form to collect identity data and request a code; Enter submits.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/access_repo_provider.dart';
import '../../domain/models/access_identity.dart';

class AccessEmailRequestResult {
  final AccessIdentity identity;
  const AccessEmailRequestResult(this.identity);
}

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
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  bool get _usernameValid => _usernameCtrl.text.trim().isNotEmpty;
  bool get _emailValid {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return true;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
  }

  bool get _phoneValid {
    final v = _phoneCtrl.text.trim();
    if (v.isEmpty) return true;
    return RegExp(r'^[0-9+\-\s]{6,20}$').hasMatch(v);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_usernameValid || !_emailValid || !_phoneValid || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final identity = AccessIdentity(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        message: _messageCtrl.text.trim().isEmpty
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
                              'Renseignez votre identifiant et vos coordonnées pour recevoir un code de confirmation.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            isWide
                                ? Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: _usernameField()),
                                          const SizedBox(width: 12),
                                          Expanded(child: _emailField()),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: _phoneField()),
                                          const SizedBox(width: 12),
                                          Expanded(child: _nameField()),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _messageField(),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: 200,
                                        height: 48,
                                        child: _primaryBtn(),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _usernameField(),
                                      const SizedBox(height: 12),
                                      _emailField(),
                                      const SizedBox(height: 12),
                                      _phoneField(),
                                      const SizedBox(height: 12),
                                      _nameField(),
                                      const SizedBox(height: 12),
                                      _messageField(),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: _primaryBtn(),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 12),
                            Text(
                              'Seul le nom d’utilisateur est obligatoire.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
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

  Widget _usernameField() {
    return TextFormField(
      controller: _usernameCtrl,
      focusNode: _usernameFocus,
      decoration: InputDecoration(
        labelText: 'Nom d’utilisateur',
        hintText: 'votre-identifiant',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _usernameCtrl.text.isEmpty ? 'Champ requis' : null,
      ),
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailCtrl,
      decoration: InputDecoration(
        labelText: 'Adresse e-mail',
        hintText: 'exemple@domaine.com',
        prefixIcon: const Icon(Icons.alternate_email),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _emailValid ? null : 'E-mail invalide',
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      decoration: InputDecoration(
        labelText: 'Téléphone',
        hintText: '+221 77 000 00 00',
        prefixIcon: const Icon(Icons.phone_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _phoneValid ? null : 'Numéro invalide',
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
    return ElevatedButton.icon(
      onPressed: _usernameValid && _emailValid && _phoneValid && !_sending
          ? _submit
          : null,
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
