// Right-drawer to reset a password by submitting a token and a new password.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/access_repo_provider.dart';

class AccessResetPasswordPanel extends ConsumerStatefulWidget {
  final String? initialToken;
  const AccessResetPasswordPanel({super.key, this.initialToken});

  @override
  ConsumerState<AccessResetPasswordPanel> createState() =>
      _AccessResetPasswordPanelState();
}

class _AccessResetPasswordPanelState
    extends ConsumerState<AccessResetPasswordPanel> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _tokenFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tokenCtrl.text = widget.initialToken ?? '';
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _tokenFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _validToken => _tokenCtrl.text.trim().isNotEmpty;
  bool get _validPass => _passCtrl.text.length >= 4;
  bool get _match => _passCtrl.text == _pass2Ctrl.text;

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_validToken || !_validPass || !_match || _busy) return;
    setState(() => _busy = true);
    try {
      final uc = ref.read(resetPasswordUseCaseProvider);
      await uc.execute(_tokenCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé avec succès.')),
      );
      Navigator.of(context).pop<bool>(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Échec de la réinitialisation. Vérifiez le token.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
            title: const Text('Réinitialiser le mot de passe'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Collez le token reçu et choisissez un nouveau mot de passe.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tokenCtrl,
                          focusNode: _tokenFocus,
                          decoration: InputDecoration(
                            labelText: 'Token de réinitialisation',
                            hintText: 'xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passFocus.requestFocus(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passCtrl,
                          focusNode: _passFocus,
                          decoration: InputDecoration(
                            labelText: 'Nouveau mot de passe',
                            hintText: 'Au moins 4 caractères',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              tooltip: _obscure ? 'Afficher' : 'Masquer',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              (v == null || v.length < 4) ? 'Trop court' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass2Ctrl,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            prefixIcon: const Icon(Icons.lock_reset),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v != _passCtrl.text)
                              ? 'Les mots de passe ne correspondent pas'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: !_busy ? _submit : null,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Réinitialiser'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
