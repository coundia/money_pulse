// Right-drawer to login using phone number and one-time code with Enter-to-validate, resend support, and request-code shortcut.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/access_grant.dart';
import '../../domain/models/access_identity.dart';
import '../providers/access_repo_provider.dart';
import 'access_email_request_panel.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class AccessPasswordLoginPanel extends ConsumerStatefulWidget {
  const AccessPasswordLoginPanel({super.key});

  @override
  ConsumerState<AccessPasswordLoginPanel> createState() =>
      _AccessPasswordLoginPanelState();
}

class _AccessPasswordLoginPanelState
    extends ConsumerState<AccessPasswordLoginPanel> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  bool _busy = false;
  bool _resending = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _validPhone =>
      RegExp(r'^[0-9]{6,20}$').hasMatch(_phoneCtrl.text.trim());
  bool get _validCode =>
      RegExp(r'^[0-9]{2,18}$').hasMatch(_codeCtrl.text.trim());

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_validPhone || !_validCode || _busy) {
      if (!_validPhone)
        _phoneFocus.requestFocus();
      else if (!_validCode)
        _codeFocus.requestFocus();
      return;
    }
    setState(() => _busy = true);
    try {
      final identity = AccessIdentity(
        username: _phoneCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      final uc = ref.read(verifyAccessUseCaseProvider);
      final grant = await uc.execute(identity, _codeCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop<AccessGrant>(grant);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide ou expiré. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || !_validPhone) {
      if (!_validPhone) _phoneFocus.requestFocus();
      return;
    }
    setState(() => _resending = true);
    try {
      final identity = AccessIdentity(
        username: _phoneCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      final uc = ref.read(requestAccessUseCaseProvider);
      await uc.execute(identity);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nouveau code envoyé.')));
      _codeFocus.requestFocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Échec de renvoi du code.')));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _openRequestCode() async {
    final res = await showRightDrawer<AccessEmailRequestResult?>(
      context,
      child: AccessEmailRequestPanel(
        initialPhone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
      ),
      widthFraction: 0.86,
      heightFraction: 1.0,
    );
    if (!mounted) return;
    if (res != null) {
      _phoneCtrl.text = res.identity.phone ?? res.identity.username;
      _codeCtrl.clear();
      _codeFocus.requestFocus();
      setState(() {});
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
          appBar: AppBar(title: const Text('Se connecter'), centerTitle: true),
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
                            const Text(
                              'Entrez votre numéro et le code reçu pour accéder à votre compte.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (isWide)
                              Row(
                                children: [
                                  Expanded(child: _phoneField()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _codeField()),
                                ],
                              )
                            else ...[
                              _phoneField(),
                              const SizedBox(height: 12),
                              _codeField(),
                            ],
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: _openRequestCode,
                                    icon: const Icon(Icons.sms_outlined),
                                    label: const Text('Recevoir un code'),
                                  ),
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
                            const SizedBox(height: 12),
                            SizedBox(
                              width: isWide ? 200 : double.infinity,
                              height: 48,
                              child: _primaryBtn(),
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

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      focusNode: _phoneFocus,
      decoration: InputDecoration(
        labelText: 'Téléphone',
        hintText: '770000000',
        prefixIcon: const Icon(Icons.phone_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      maxLength: 15,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _codeFocus.requestFocus(),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Champ requis'
          : (_validPhone ? null : 'Numéro invalide'),
    );
  }

  Widget _codeField() {
    return TextFormField(
      controller: _codeCtrl,
      focusNode: _codeFocus,
      decoration: InputDecoration(
        labelText: 'Code',
        hintText: '123456',
        prefixIcon: const Icon(Icons.verified_user_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      maxLength: 8,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Champ requis'
          : (_validCode ? null : 'Code invalide'),
    );
  }

  Widget _primaryBtn() {
    return ElevatedButton.icon(
      onPressed: !_busy ? _submit : null,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login),
      label: const Text('Se connecter'),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
