// Auto refresh wrapper filtered by a tag for both popNext and app resume.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:money_pulse/presentation/navigation/route_observer.dart';
import 'package:money_pulse/presentation/navigation/refocus_bus.dart';

class AutoRefreshOnFocus extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefocus;
  final bool immediate;
  final Duration debounce;
  final bool loggingEnabled;
  final String logTag;
  final String? onlyWhenTag;

  const AutoRefreshOnFocus({
    super.key,
    required this.child,
    required this.onRefocus,
    this.immediate = false,
    this.debounce = const Duration(milliseconds: 350),
    this.loggingEnabled = true,
    this.logTag = 'AutoRefreshOnFocus',
    this.onlyWhenTag = 'chatbot',
  });

  @override
  State<AutoRefreshOnFocus> createState() => _AutoRefreshOnFocusState();
}

class _AutoRefreshOnFocusState extends State<AutoRefreshOnFocus>
    with RouteAware, WidgetsBindingObserver {
  ModalRoute<dynamic>? _route;
  bool _running = false;
  DateTime? _lastRun;

  @override
  void initState() {
    print("[####### AutoRefreshOnFocus ]");
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.immediate) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _trigger());
    }
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

  @override
  void didPopNext() {
    final expected = widget.onlyWhenTag;
    if (expected != null) {
      final tag = RefocusBus.take();
      if (tag != expected) return;
    }
    _trigger();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final expected = widget.onlyWhenTag;
      if (expected != null) {
        final tag = RefocusBus.take();
        if (tag != expected) return;
      }
      _trigger();
    }
  }

  void _trigger() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastRun != null && now.difference(_lastRun!) < widget.debounce) return;
    if (_running) return;
    _running = true;
    _lastRun = now;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await widget.onRefocus();
      } finally {
        _running = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
