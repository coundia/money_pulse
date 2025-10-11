// File: lib/presentation/widgets/auto_refresh_on_focus.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:money_pulse/presentation/navigation/route_observer.dart';

/// Wrappe n'importe quelle page.
/// Déclenche [onRefocus] automatiquement:
///  - quand la page redevient visible (didPopNext)
///  - quand l'app repasse en avant-plan (AppLifecycleState.resumed)
class AutoRefreshOnFocus extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefocus;

  const AutoRefreshOnFocus({
    super.key,
    required this.child,
    required this.onRefocus,
  });

  @override
  State<AutoRefreshOnFocus> createState() => _AutoRefreshOnFocusState();
}

class _AutoRefreshOnFocusState extends State<AutoRefreshOnFocus>
    with RouteAware, WidgetsBindingObserver {
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Prêt immédiatement après le premier frame
    SchedulerBinding.instance.addPostFrameCallback((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (_route != r && r != null) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = r;
      routeObserver.subscribe(this, r);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) routeObserver.unsubscribe(this);
    super.dispose();
  }

  // — RouteAware —

  /// Appelé quand on revient sur cette page (ex: on a pop une autre route).
  @override
  void didPopNext() => _trigger();

  @override
  void didPushNext() {
    // no-op
  }

  // — Cycle de vie de l’app —

  /// Quand l’app revient en avant-plan, relancer un refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _trigger();
  }

  void _trigger() {
    if (!mounted) return;
    // Laisse le layout finir avant de lancer le refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.onRefocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
