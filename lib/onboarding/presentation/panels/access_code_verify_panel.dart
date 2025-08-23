// Right-drawer: code verification form with resend, responsive layout, and Enter-to-verify.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/access_grant.dart';
import '../providers/access_repo_provider.dart';

class AccessCodeVerifyPanel extends ConsumerStatefulWidget {
  final String email;
  const AccessCodeVerifyPanel({super.key, required this.email});

  @override
  ConsumerState<AccessCodeVerifyPanel> createState() =>
      _AccessCodeVerifyPanelState();
}

class _AccessCodeVerifyPanelState extends ConsumerState<AccessCodeVerifyPanel> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  bool _verifying = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _codeValid {
    final v = _codeCtrl.text.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^\d{4,8}$').hasMatch(v);
  }

  Future<void> _verify() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_codeValid || _verifying) return;
    setState(() => _verifying = true);
    try {
      final uc = ref.read(verifyAccessUseCaseProvider);
      final grant = await uc.execute(widget.email, _codeCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop<AccessGrant>(grant);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide ou expiré. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final uc = ref.read(requestAccessUseCaseProvider);
      await uc.execute(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nouveau code envoyé.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Échec de renvoi du code.')));
    } finally {
      if (mounted) setState(() => _resending = false);
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
              _verify();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Saisir le code'),
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
                              'Un code a été envoyé à ${widget.email}. Entrez-le pour valider votre accès.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(child: _codeField()),
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
                                      _codeField(),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: _primaryBtn(),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _resending ? null : _resend,
                              icon: _resending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: const Text('Renvoyer le code'),
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

  Widget _codeField() {
    return TextFormField(
      controller: _codeCtrl,
      focusNode: _codeFocus,
      decoration: InputDecoration(
        labelText: 'Code de confirmation',
        hintText: '6 chiffres',
        prefixIcon: const Icon(Icons.verified_user_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
        errorText: _codeCtrl.text.isEmpty
            ? null
            : (_codeValid ? null : 'Code invalide'),
      ),
      maxLength: 6,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _verify(),
    );
  }

  Widget _primaryBtn() {
    return ElevatedButton.icon(
      onPressed: _codeValid && !_verifying ? _verify : null,
      icon: _verifying
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check),
      label: const Text('Valider'),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
