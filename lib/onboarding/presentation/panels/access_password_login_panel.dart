// Right-drawer to login with alphanumeric username and password, Enter-to-validate, and forgot-password flow.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/access_grant.dart';
import '../providers/access_repo_provider.dart';
import 'access_forgot_password_panel.dart';
import 'access_reset_password_panel.dart';

class AccessPasswordLoginPanel extends ConsumerStatefulWidget {
  const AccessPasswordLoginPanel({super.key});

  @override
  ConsumerState<AccessPasswordLoginPanel> createState() =>
      _AccessPasswordLoginPanelState();
}

class _AccessPasswordLoginPanelState
    extends ConsumerState<AccessPasswordLoginPanel> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      _userCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty;

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final uc = ref.read(loginWithPasswordUseCaseProvider);
      final grant = await uc.execute(_userCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop<AccessGrant>(grant);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifiants invalides. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForgotFlow() async {
    final sent = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AccessForgotPasswordPanel(
          initialUsername: _userCtrl.text.trim().isNotEmpty
              ? _userCtrl.text.trim()
              : null,
        ),
      ),
    );
    if (sent == true && mounted) {
      final resetOk = await showModalBottomSheet<bool?>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const AccessResetPasswordPanel(),
      );
      if (resetOk == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe mis à jour. Connectez-vous.'),
          ),
        );
        _passCtrl.clear();
        _userFocus.requestFocus();
      }
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
          appBar: AppBar(title: const Text('Se connecter'), centerTitle: true),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 560;
                return Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Entrez votre identifiant et votre mot de passe (alphanumériques) pour accéder à votre compte.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (isWide)
                              Row(
                                children: [
                                  Expanded(child: _userField()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _passField()),
                                ],
                              )
                            else ...[
                              _userField(),
                              const SizedBox(height: 12),
                              _passField(),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: isWide ? 200 : double.infinity,
                              height: 48,
                              child: _primaryBtn(),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _openForgotFlow,
                                icon: const Icon(Icons.help_outline),
                                label: const Text('Mot de passe oublié ?'),
                              ),
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

  Widget _userField() {
    return TextFormField(
      controller: _userCtrl,
      focusNode: _userFocus,
      decoration: InputDecoration(
        labelText: 'Identifiant',
        hintText: 'Telephone ou email',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: TextInputType.text,
      // no inputFormatters to allow alphanumerics and common symbols
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _passFocus.requestFocus(),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
    );
  }

  Widget _passField() {
    return TextFormField(
      controller: _passCtrl,
      focusNode: _passFocus,
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        hintText: 'Au moins 4 caractères',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscure ? 'Afficher' : 'Masquer',
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      obscureText: _obscure,
      keyboardType: TextInputType.text,
      // no inputFormatters -> alphanumeric and symbols allowed
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: (v) => (v == null || v.length < 4) ? 'Trop court' : null,
    );
  }

  Widget _primaryBtn() {
    return ElevatedButton.icon(
      onPressed: !_busy ? _submit : null,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login),
      label: const Text('Se connecter'),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
