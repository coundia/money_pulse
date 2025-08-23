// Flow orchestration: open email panel then code panel with right_drawer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/widgets/right_drawer.dart';
import '../panels/access_email_request_panel.dart';
import '../panels/access_code_verify_panel.dart';
import '../../domain/entities/access_grant.dart';

Future<AccessGrant?> startAccessFlow(
  BuildContext context,
  WidgetRef ref, {
  String? prefillEmail,
}) async {
  final emailRes = await showRightDrawer<AccessEmailRequestResult?>(
    context,
    child: AccessEmailRequestPanel(initialEmail: prefillEmail),
    widthFraction: 0.86,
    heightFraction: 1.0,
  );
  if (emailRes == null) return null;

  final grant = await showRightDrawer<AccessGrant?>(
    context,
    child: AccessCodeVerifyPanel(email: emailRes.email),
    widthFraction: 0.86,
    heightFraction: 1.0,
  );
  return grant;
}
