/// Responsive login page in French with Enter-to-submit and accessibility.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_fields.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loadingUi = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() => _loadingUi = true);
    await ref
        .read(authControllerProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text.trim());
    setState(() => _loadingUi = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isBusy = auth.isLoading || _loadingUi;

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
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
                              const SizedBox(height: 12),
                              PasswordField(
                                controller: _passCtrl,
                                onSubmitted: _submit,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: isBusy ? null : _submit,
                                  icon: const Icon(Icons.login),
                                  label: Text(
                                    isBusy ? 'Connexion…' : 'Se connecter',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => Navigator.of(
                                          context,
                                        ).pushNamed('/forgot'),
                                  child: const Text('Mot de passe oublié ?'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: isBusy
                                    ? null
                                    : () => Navigator.of(
                                        context,
                                      ).pushNamed('/register'),
                                child: const Text('Créer un compte'),
                              ),
                              if (auth.error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  auth.error!,
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
