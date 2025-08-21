/// Route table entries for login, register, forgot and reset pages.
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';

Map<String, WidgetBuilder> authRoutes() {
  return {
    '/login': (_) => const LoginPage(),
    '/register': (_) => const RegisterPage(),
    '/forgot': (_) => const ForgotPasswordPage(),
    '/reset': (ctx) {
      final args = ModalRoute.of(ctx)?.settings.arguments;
      final token = args is String ? args : null;
      return ResetPasswordPage(token: token);
    },
  };
}
