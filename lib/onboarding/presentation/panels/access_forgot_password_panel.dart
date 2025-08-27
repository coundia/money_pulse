// Right-drawer to request a password reset link or code by username.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/access_repo_provider.dart';

class AccessForgotPasswordPanel extends ConsumerStatefulWidget {
  final String? initialUsername;
  const AccessForgotPasswordPanel({super.key, this.initialUsername});

  @override
  ConsumerState<AccessForgotPasswordPanel> createState() =>
      _AccessForgotPasswordPanelState();
}

class _AccessForgotPasswordPanelState
    extends ConsumerState<AccessForgotPasswordPanel> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _userFocus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _userCtrl.text = widget.initialUsername ?? '';
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _userFocus.dispose();
    super.dispose();
  }

  bool get _valid => _userCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final uc = ref.read(forgotPasswordUseCaseProvider);
      await uc.execute(_userCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instructions envoyées. Vérifiez vos messages.'),
        ),
      );
      Navigator.of(context).pop<bool>(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l’envoi. Réessayez.')),
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
            title: const Text('Mot de passe oublié'),
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
                          'Entrez votre identifiant ou e-mail pour recevoir un lien ou un code de réinitialisation.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _userCtrl,
                          focusNode: _userFocus,
                          decoration: InputDecoration(
                            labelText: 'Identifiant ou e-mail',
                            hintText: 'admin ou exemple@domaine.com',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
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
                                : const Icon(Icons.send),
                            label: const Text('Envoyer'),
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
