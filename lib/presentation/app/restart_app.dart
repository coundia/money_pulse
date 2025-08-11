import 'package:flutter/widgets.dart';

class RestartApp extends StatefulWidget {
  final Widget child;
  const RestartApp({super.key, required this.child});

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartAppState>()?.restart();
  }

  @override
  State<RestartApp> createState() => _RestartAppState();
}

class _RestartAppState extends State<RestartApp> {
  Key _key = UniqueKey();

  void restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
