// Flow: collect identity or password login, then verify; both in right-drawers.
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
  final first = await showRightDrawer<dynamic>(
    context,
    child: AccessEmailRequestPanel(initialPhone: prefillEmail),
    widthFraction: 0.86,
    heightFraction: 1.0,
  );
  if (first == null) return null;

  if (first is AccessGrant) {
    return first;
  }

  final emailRes = first as AccessEmailRequestResult;
  final grant = await showRightDrawer<AccessGrant?>(
    context,
    child: AccessCodeVerifyPanel(identity: emailRes.identity),
    widthFraction: 0.86,
    heightFraction: 1.0,
  );
  return grant;
}
