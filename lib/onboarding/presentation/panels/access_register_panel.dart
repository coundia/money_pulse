// Register form that surfaces server error messages and logs them.
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/onboarding/presentation/providers/access_repo_provider.dart'
    show registerWithPasswordUseCaseProvider;
import '../providers/access_session_provider.dart';
import '../../../presentation/features/home/home_page.dart';
import '../../infrastructure/api_error.dart';

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

  String? _userWarn;
  String? _passWarn;
  String? _pass2Warn;
  String? _formWarn;

  @override
  void initState() {
    super.initState();
    _userCtrl.text = widget.initialUsername ?? '';
    _userCtrl.addListener(_clearFieldWarnings);
    _passCtrl.addListener(_clearFieldWarnings);
    _pass2Ctrl.addListener(_clearFieldWarnings);
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

  void _clearFieldWarnings() {
    if (_userWarn != null ||
        _passWarn != null ||
        _pass2Warn != null ||
        _formWarn != null) {
      setState(() {
        _userWarn = null;
        _passWarn = null;
        _pass2Warn = null;
        _formWarn = null;
      });
    }
  }

  bool get _validUser => _userCtrl.text.trim().isNotEmpty;
  bool get _validPass => _passCtrl.text.length >= 4;
  bool get _match => _passCtrl.text == _pass2Ctrl.text;

  bool _validateGently() {
    String? u, p, p2;
    if (!_validUser) u = 'Identifiant requis';
    if (!_validPass) p = 'Mot de passe trop court (≥ 4)';
    if (!_match) p2 = 'Les mots de passe ne correspondent pas';
    setState(() {
      _userWarn = u;
      _passWarn = p;
      _pass2Warn = p2;
    });
    return u == null && p == null && p2 == null;
  }

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
    if (_busy) return;
    final ok = _validateGently();
    if (!ok) {
      if (!_validUser) {
        _userFocus.requestFocus();
      } else if (!_validPass) {
        _passFocus.requestFocus();
      }
      return;
    }

    setState(() {
      _busy = true;
      _formWarn = null;
    });

    try {
      final uc = ref.read(registerWithPasswordUseCaseProvider);
      final grant = await uc.execute(_userCtrl.text.trim(), _passCtrl.text);
      await ref.read(accessSessionProvider.notifier).save(grant);
      if (!mounted) return;
      _openHomeAfterFrame();
    } catch (e, st) {
      final msg = _errorToUserMessage(e);
      dev.log(
        'Register failed',
        name: 'AccessRegisterPanel',
        error: {'message': msg, 'error': e.toString()},
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _formWarn = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorToUserMessage(Object e) {
    if (e is ApiError) {
      if (e.message.trim().isNotEmpty) return e.message.trim();
      return 'Erreur $e';
    }
    final s = e.toString();
    if (s.contains('network') || s.contains('SocketException')) {
      return 'Connexion indisponible. Vérifiez votre réseau et réessayez.';
    }
    if (s.toLowerCase().contains('already') ||
        s.toLowerCase().contains('exists')) {
      return 'Cet identifiant est déjà utilisé. Choisissez-en un autre.';
    }
    return 'Échec de la création du compte. Réessayez.';
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
                    autovalidateMode: AutovalidateMode.disabled,
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
                            helperText: _userWarn,
                            helperMaxLines: 3,
                            helperStyle: TextStyle(
                              color: Colors.amber.shade800,
                              fontSize: 12.5,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passFocus.requestFocus(),
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
                            helperText: _passWarn,
                            helperMaxLines: 3,
                            helperStyle: TextStyle(
                              color: Colors.amber.shade800,
                              fontSize: 12.5,
                            ),
                          ),
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
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
                            helperText: _pass2Warn,
                            helperMaxLines: 3,
                            helperStyle: TextStyle(
                              color: Colors.amber.shade800,
                              fontSize: 12.5,
                            ),
                          ),
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: (_formWarn == null)
                              ? const SizedBox.shrink()
                              : Padding(
                                  key: const ValueKey('warn'),
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formWarn!,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
