import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';

class LifecycleLogger with WidgetsBindingObserver {
  static final LifecycleLogger I = LifecycleLogger._();
  LifecycleLogger._();

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    dev.log('LifecycleLogger attached', name: 'AppLifecycle');
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    dev.log('LifecycleLogger detached', name: 'AppLifecycle');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    dev.log('AppLifecycleState=$state', name: 'AppLifecycle');
  }

  @override
  void didHaveMemoryPressure() {
    dev.log('!!! didHaveMemoryPressure', name: 'AppLifecycle');
  }
}
