/// Reusable email and password fields with Enter-to-submit behavior.
import 'package:flutter/material.dart';

class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const EmailField({super.key, required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Adresse e-mail',
        hintText: 'nom@domaine.com',
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'E-mail requis' : null,
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const PasswordField({super.key, required this.controller, this.onSubmitted});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Afficher' : 'Masquer',
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().length < 6) ? '6 caractères minimum' : null,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    );
  }
}
