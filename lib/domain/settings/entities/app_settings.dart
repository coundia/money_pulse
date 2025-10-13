/// App settings entity with simple flags.

class AppSettings {
  final bool autoRefreshOnFocus;

  const AppSettings({required this.autoRefreshOnFocus});

  AppSettings copyWith({bool? autoRefreshOnFocus}) => AppSettings(
    autoRefreshOnFocus: autoRefreshOnFocus ?? this.autoRefreshOnFocus,
  );

  static const defaults = AppSettings(autoRefreshOnFocus: true);
}
