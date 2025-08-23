// Right-drawer: email request form with responsive layout and Enter-to-submit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/access_repo_provider.dart';

class AccessEmailRequestResult {
  final String email;
  const AccessEmailRequestResult(this.email);
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
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_emailValid || _sending) return;
    setState(() => _sending = true);
    try {
      final uc = ref.read(requestAccessUseCaseProvider);
      await uc.execute(_emailCtrl.text);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(AccessEmailRequestResult(_emailCtrl.text.trim()));
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
                            Text(
                              'Entrez votre adresse e-mail pour recevoir un code de confirmation et accéder à toutes les fonctionnalités.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(child: _emailField()),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 160,
                                        height: 48,
                                        child: _primaryBtn(),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _emailField(),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: _primaryBtn(),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 12),
                            Text(
                              'Vos informations ne seront utilisées que pour la vérification.',
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

  Widget _emailField() {
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
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _primaryBtn() {
    return ElevatedButton.icon(
      onPressed: _emailValid && !_sending ? _submit : null,
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
