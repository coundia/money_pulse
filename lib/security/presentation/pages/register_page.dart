/// Responsive registration page in French with Enter-to-submit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_fields.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loadingUi = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
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
        .register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
        );
    setState(() => _loadingUi = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isBusy = auth.isLoading || _loadingUi;

    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
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
                                controller: _nameCtrl,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nom complet',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Nom requis'
                                    : null,
                                onFieldSubmitted: (_) {},
                              ),
                              const SizedBox(height: 12),
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
                                  icon: const Icon(Icons.person_add),
                                  label: Text(
                                    isBusy ? 'Création…' : 'Créer mon compte',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: isBusy
                                    ? null
                                    : () => Navigator.of(
                                        context,
                                      ).pushReplacementNamed('/login'),
                                child: const Text(
                                  'Déjà inscrit ? Se connecter',
                                ),
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
