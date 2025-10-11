// File: lib/presentation/widgets/auto_refresh_on_focus.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:money_pulse/presentation/navigation/route_observer.dart';

/// Wrappe n'importe quelle page.
/// Déclenche [onRefocus] automatiquement:
///  - quand la page redevient visible (didPopNext)
///  - quand l'app repasse en avant-plan (AppLifecycleState.resumed)
/// Options:
///  - [immediate]: lance aussi le refresh juste après le premier frame
///  - [debounce]: anti-"double tir" si les événements s'enchaînent (popNext + resumed)
///  - [loggingEnabled]: active des logs détaillés dans la console (dev.log)
///  - [logTag]: tag utilisé pour les logs (par défaut: "AutoRefreshOnFocus")
class AutoRefreshOnFocus extends StatefulWidget {
  final Widget child;

  /// Ton callback de rafraîchissement. Par ex. dans HomePage:
  /// onRefocus: () => _refreshAll(remount: true)
  final Future<void> Function() onRefocus;

  /// Lancer le refresh immédiatement au premier affichage ?
  final bool immediate;

  /// Délai minimal entre deux rafraîchissements auto.
  final Duration debounce;

  /// Active les logs (dev.log)
  final bool loggingEnabled;

  /// Tag de logs.
  final String logTag;

  const AutoRefreshOnFocus({
    super.key,
    required this.child,
    required this.onRefocus,
    this.immediate = false,
    this.debounce = const Duration(milliseconds: 350),
    this.loggingEnabled = true,
    this.logTag = 'AutoRefreshOnFocus',
  });

  @override
  State<AutoRefreshOnFocus> createState() => _AutoRefreshOnFocusState();
}

class _AutoRefreshOnFocusState extends State<AutoRefreshOnFocus>
    with RouteAware, WidgetsBindingObserver {
  ModalRoute<dynamic>? _route;

  bool _running = false;
  DateTime? _lastRun;

  void _log(String msg, {Object? error, StackTrace? st}) {
    if (!widget.loggingEnabled) return;
    dev.log(msg, name: widget.logTag, error: error, stackTrace: st);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _log(
      'initState() — observer added, immediate=${widget.immediate}, debounce=${widget.debounce.inMilliseconds}ms',
    );

    // Déclenchement optionnel dès le premier affichage
    if (widget.immediate) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _log('postFrame (immediate=true) -> trigger');
        _trigger(reason: 'immediate_first_frame');
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (_route != r && r != null) {
      if (_route != null) {
        _log('didChangeDependencies() — route changed, unsubscribe previous');
        routeObserver.unsubscribe(this);
      }
      _route = r;
      _log('didChangeDependencies() — subscribe new route=$r');
      routeObserver.subscribe(this, r);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) {
      _log('dispose() — unsubscribe route');
      routeObserver.unsubscribe(this);
    }
    _log('dispose() — observer removed');
    super.dispose();
  }

  // — RouteAware —

  /// Appelé quand on revient sur cette page (ex: on a pop une autre route).
  @override
  void didPopNext() {
    _log('didPopNext() -> trigger');
    _trigger(reason: 'didPopNext');
  }

  @override
  void didPushNext() {
    _log('didPushNext() — pushed next route (pausing here)');
  }

  // — Cycle de vie de l’app —

  /// Quand l’app revient en avant-plan, relancer un refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('didChangeAppLifecycleState($state)');
    if (state == AppLifecycleState.resumed) {
      _log('AppLifecycleState.resumed -> trigger');
      _trigger(reason: 'app_resumed');
    }
  }

  void _trigger({String reason = 'unknown'}) {
    if (!mounted) {
      _log('trigger($reason) ignored — not mounted');
      return;
    }

    final now = DateTime.now();

    // Debounce
    if (_lastRun != null && now.difference(_lastRun!) < widget.debounce) {
      _log(
        'trigger($reason) ignored — debounce (${now.difference(_lastRun!).inMilliseconds}ms < ${widget.debounce.inMilliseconds}ms)',
      );
      return;
    }

    // Anti re-entrance
    if (_running) {
      _log('trigger($reason) ignored — already running');
      return;
    }

    _running = true;
    _lastRun = now;
    _log('trigger($reason) — START at $now');

    // Laisse le layout finir avant de lancer le refresh async
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          _log('trigger($reason) aborted — not mounted in postFrame');
          return;
        }
        await widget.onRefocus();
        _log('trigger($reason) — DONE');
      } catch (e, st) {
        _log('trigger($reason) — ERROR', error: e, st: st);
      } finally {
        _running = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
