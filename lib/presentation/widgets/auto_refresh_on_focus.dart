/// No-op shim for AutoRefreshOnFocus.
/// This version DOES NOT subscribe to RouteObserver or app lifecycle,
/// and NEVER triggers the onRefocus callback. It simply renders [child].
///
/// Keep this file if existing pages still import/use AutoRefreshOnFocus;
/// nothing will auto-refresh anymore.

import 'package:flutter/widgets.dart';

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
    this.loggingEnabled = false,
    this.logTag = 'AutoRefreshOnFocus',
    this.onlyWhenTag,
  });

  @override
  State<AutoRefreshOnFocus> createState() => _AutoRefreshOnFocusState();
}

class _AutoRefreshOnFocusState extends State<AutoRefreshOnFocus> {
  @override
  Widget build(BuildContext context) => widget.child;
}
