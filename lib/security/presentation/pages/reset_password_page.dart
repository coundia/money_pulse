/// Responsive page to set a new password using a token with Enter-to-submit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  final String? token;
  const ResetPasswordPage({super.key, this.token});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _busy = false;
  String? _doneMsg;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.token != null && widget.token!.isNotEmpty) {
      _tokenCtrl.text = widget.token!;
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() {
      _busy = true;
      _doneMsg = null;
      _error = null;
    });
    try {
      await ref
          .read(confirmPasswordResetUseCaseProvider)
          .execute(
            token: _tokenCtrl.text.trim(),
            newPassword: _passCtrl.text.trim(),
          );
      setState(
        () => _doneMsg = 'Mot de passe mis à jour. Vous pouvez vous connecter.',
      );
    } catch (_) {
      setState(() => _error = 'Échec de réinitialisation.');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réinitialiser le mot de passe')),
      body: FocusTraversalGroup(
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => _submit(),
              ),
            },
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth >= 720;
                  final cardWidth = isWide ? 520.0 : c.maxWidth * 0.94;
                  return ConstrainedBox(
                    constraints: BoxConstraints.tightFor(width: cardWidth),
                    child: Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: _tokenCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Jeton de réinitialisation',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Jeton requis'
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Nouveau mot de passe',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 6)
                                    ? '6 caractères minimum'
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pass2Ctrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmer le mot de passe',
                                ),
                                validator: (v) => (v != _passCtrl.text)
                                    ? 'Les mots de passe ne correspondent pas'
                                    : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _submit,
                                  icon: const Icon(Icons.lock_reset),
                                  label: Text(
                                    _busy ? 'Validation…' : 'Mettre à jour',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(
                                        context,
                                      ).pushReplacementNamed('/login'),
                                child: const Text('Retour à la connexion'),
                              ),
                              if (_doneMsg != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _doneMsg!,
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
