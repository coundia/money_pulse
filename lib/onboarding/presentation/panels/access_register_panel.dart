// Right-drawer to register, persist session, then open HomePage by replacing the whole stack.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_repo_provider.dart'
    show registerWithPasswordUseCaseProvider;
import '../providers/access_session_provider.dart';
import '../../../presentation/features/home/home_page.dart';

class AccessRegisterPanel extends ConsumerStatefulWidget {
  final String? initialUsername;
  const AccessRegisterPanel({super.key, this.initialUsername});

  @override
  ConsumerState<AccessRegisterPanel> createState() =>
      _AccessRegisterPanelState();
}

class _AccessRegisterPanelState extends ConsumerState<AccessRegisterPanel> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _userCtrl.text = widget.initialUsername ?? '';
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _validUser => _userCtrl.text.trim().isNotEmpty;
  bool get _validPass =>
      _passCtrl.text.length >= 4 && _passCtrl.text == _pass2Ctrl.text;

  void _openHomeAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    });
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_validUser || !_validPass || _busy) return;
    setState(() => _busy = true);
    try {
      final uc = ref.read(registerWithPasswordUseCaseProvider);
      final grant = await uc.execute(_userCtrl.text.trim(), _passCtrl.text);
      await ref.read(accessSessionProvider.notifier).save(grant);
      if (!mounted) return;
      _openHomeAfterFrame();
    } catch (_) {
      if (!mounted) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop(true);
      });
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
            title: const Text('Créer un compte'),
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
                          'Choisissez un identifiant et un mot de passe pour créer votre compte.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _userCtrl,
                          focusNode: _userFocus,
                          decoration: InputDecoration(
                            labelText: 'Identifiant',
                            hintText: 'Email ou Téléphone',
                            prefixIcon: const Icon(Icons.person_add_alt),
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
                            labelText: 'Mot de passe',
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
                                : const Icon(Icons.person_add),
                            label: const Text('Créer le compte'),
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
