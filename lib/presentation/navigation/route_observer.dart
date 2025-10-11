// File: lib/presentation/navigation/route_observer.dart
import 'package:flutter/widgets.dart';

/// RouteObserver global, à brancher sur MaterialApp.navigatorObservers.
/// Permet d'être notifié quand une page redevient visible (didPopNext).
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
