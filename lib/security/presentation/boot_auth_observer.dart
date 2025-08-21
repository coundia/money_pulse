/// App bootstrap observer to auto-load session at startup.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_providers.dart';

class BootAuthObserver extends ConsumerStatefulWidget {
  final Widget child;
  const BootAuthObserver({super.key, required this.child});

  @override
  ConsumerState<BootAuthObserver> createState() => _BootAuthObserverState();
}

class _BootAuthObserverState extends ConsumerState<BootAuthObserver> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
