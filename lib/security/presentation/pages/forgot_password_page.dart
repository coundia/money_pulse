/// Responsive page to request a password reset email with Enter-to-submit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_fields.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() {
      _sending = true;
      _message = null;
      _error = null;
    });
    try {
      await ref
          .read(requestPasswordResetUseCaseProvider)
          .execute(email: _emailCtrl.text.trim());
      setState(
        () => _message = 'Si cette adresse existe, un e-mail a été envoyé.',
      );
    } catch (_) {
      setState(() => _error = 'Impossible d’envoyer la demande.');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
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
                              const SizedBox(height: 8),
                              EmailField(
                                controller: _emailCtrl,
                                onSubmitted: _submit,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 48,
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _sending ? null : _submit,
                                  icon: const Icon(Icons.mail_outline),
                                  label: Text(
                                    _sending ? 'Envoi…' : 'Envoyer le lien',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _sending
                                    ? null
                                    : () => Navigator.of(
                                        context,
                                      ).pushReplacementNamed('/login'),
                                child: const Text('Retour à la connexion'),
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _message!,
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
