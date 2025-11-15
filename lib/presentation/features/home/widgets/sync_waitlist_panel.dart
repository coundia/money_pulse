/* Right-drawer waitlist form with responsive layout, prefill from previous entry, at-least-one-contact validation, and Enter-to-submit. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jaayko/domain/waitlist/entities/waitlist_entry.dart';
import 'package:jaayko/presentation/shared/formatters.dart';

class SyncWaitlistResult {
  final String? email;
  final String? phone;
  final String? message;
  const SyncWaitlistResult(this.email, this.phone, this.message);
}

class SyncWaitlistPanel extends StatefulWidget {
  final WaitlistEntry? initial;
  const SyncWaitlistPanel({super.key, this.initial});

  @override
  State<SyncWaitlistPanel> createState() => _SyncWaitlistPanelState();
}

class _SyncWaitlistPanelState extends State<SyncWaitlistPanel> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _msgFocus = FocusNode();
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _emailCtrl.text = widget.initial!.email ?? '';
      _phoneCtrl.text = widget.initial!.phone ?? '';
      _msgCtrl.text = widget.initial!.message ?? '';
    }
    _emailCtrl.addListener(_onChanged);
    _phoneCtrl.addListener(_onChanged);
    _msgCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_onChanged);
    _phoneCtrl.removeListener(_onChanged);
    _msgCtrl.removeListener(_onChanged);
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _msgFocus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_dirty) _dirty = true;
    setState(() {});
  }

  bool get _hasAnyContact =>
      _emailCtrl.text.trim().isNotEmpty || _phoneCtrl.text.trim().isNotEmpty;

  bool get _emailValid {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return true;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
  }

  bool get _phoneValid {
    final v = _phoneCtrl.text.trim();
    if (v.isEmpty) return true;
    return v.length >= 8;
  }

  bool get _canSubmit => _hasAnyContact && _emailValid && _phoneValid;

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez au moins un e-mail ou un téléphone'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      SyncWaitlistResult(
        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            title: const Text('Inscription à la liste d’attente'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 560;

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
                            if (widget.initial?.hasAnyContact == true)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Déjà inscrit le ${Formatters.dateFull(widget.initial!.savedAt)}.',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Modifier'),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              'Laissez vos coordonnées pour être averti dès que la synchronisation sera disponible.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: (!_hasAnyContact && _dirty)
                                  ? Container(
                                      key: const ValueKey('warn'),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info,
                                            color: theme
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Entrez au moins un e-mail ou un téléphone.',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onErrorContainer,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 16),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(child: _emailField()),
                                      const SizedBox(width: 16),
                                      Expanded(child: _phoneField()),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _emailField(),
                                      const SizedBox(height: 16),
                                      _phoneField(),
                                    ],
                                  ),
                            const SizedBox(height: 16),
                            _messageField(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _canSubmit ? _submit : null,
                        icon: const Icon(Icons.check),
                        label: const Text('S’inscrire'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Plus tard'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vos informations ne seront utilisées que pour vous prévenir.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
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
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _emailValid ? null : 'E-mail invalide',
      ),
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
      onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
      validator: (_) {
        if (!_hasAnyContact && _dirty)
          return 'Entrez au moins un e-mail ou un téléphone';
        if (!_emailValid) return 'E-mail invalide';
        return null;
      },
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      focusNode: _phoneFocus,
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone',
        hintText: '770000000',
        prefixIcon: const Icon(Icons.phone_android),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _phoneValid ? null : 'Numéro invalide',
      ),
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onFieldSubmitted: (_) => _msgFocus.requestFocus(),
      validator: (_) {
        if (!_hasAnyContact && _dirty)
          return 'Entrez au moins un téléphone ou un e-mail';
        if (!_phoneValid) return 'Numéro invalide';
        return null;
      },
    );
  }

  Widget _messageField() {
    return TextFormField(
      controller: _msgCtrl,
      focusNode: _msgFocus,
      decoration: InputDecoration(
        labelText: 'Message (optionnel)',
        hintText: 'Ajoutez un commentaire…',
        prefixIcon: const Icon(Icons.message_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maxLines: 3,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
    );
  }
}
