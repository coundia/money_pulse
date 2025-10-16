// File: lib/presentation/features/settings/about_page.dart
// "À propos" page with tappable phone/email/website, quick actions,
// cached logo, and robust fallbacks.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _assetPath = 'assets/logo/app_icon.png';

  bool _assetOk = true; // optimistic: assume present

  // === Replace with your real info ===
  static const String _appName = 'Money Pulse';
  static const String _version = '1.0.0';
  static const String _ownerName = 'Papa COUNDIA';
  static const String _ownerEmail = 'contact@pcoundia.com';
  static const String _ownerPhone = '+221 77 539 24 82';
  static const String _ownerWebsite = 'https://pcoundia.com';
  static const String _shortDesc =
      'Application de gestion des dépenses, des revenus etc...';

  Uri get _phoneUri {
    // Garde le + et les chiffres
    final digits = _ownerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    return Uri(scheme: 'tel', path: digits);
  }

  Uri get _emailUri => Uri(
    scheme: 'mailto',
    path: _ownerEmail,
    queryParameters: {'subject': 'Contact depuis Money Pulse'},
  );

  Uri get _websiteUri => Uri.parse(_ownerWebsite);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Try to precache; if it throws, mark as missing and log a hint.
    precacheImage(const AssetImage(_assetPath), context).catchError((e, st) {
      if (kDebugMode) {
        // Helpful hint in console when asset not visible
        debugPrint(
          '[AboutPage] Asset not found: $_assetPath.\n'
          '• Ensure the file exists at project_root/$_assetPath\n'
          '• And pubspec.yaml has:\n'
          '    flutter:\n'
          '      assets:\n'
          '        - $_assetPath\n'
          '• Then run: flutter clean && flutter pub get',
        );
      }
      if (mounted) setState(() => _assetOk = false);
    });
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copié')));
  }

  Future<void> _launch(
    Uri uri, {
    String? labelOnError,
    String? copyOnFail,
  }) async {
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) throw 'No handler';
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) throw 'Launch failed';
    } catch (_) {
      if (!mounted) return;
      final label = labelOnError ?? 'Action indisponible';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          action: (copyOnFail != null)
              ? SnackBarAction(
                  label: 'Copier',
                  onPressed: () => _copy(context, 'Lien', copyOnFail),
                )
              : null,
        ),
      );
    }
  }

  Widget _brandLogo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface;
    final border = cs.outlineVariant.withOpacity(0.6);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _assetOk
          ? Image.asset(
              _assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) {
                // If decoding fails, still show fallback
                return _fallbackLogo(context);
              },
            )
          : _fallbackLogo(context),
    );
  }

  Widget _fallbackLogo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceVariant.withOpacity(0.4),
      child: Center(
        child: Icon(Icons.analytics_rounded, size: 56, color: cs.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Brand / Header
          Center(child: _brandLogo(context)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _appName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _shortDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              label: Text('Version $_version'),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),

          // Owner / Publisher
          _Section(title: 'Éditeur'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Nom'),
                  subtitle: Text(_ownerName),
                ),
                const Divider(height: 1),

                // E-mail cliquable + long-press pour copier
                _LinkTile(
                  leading: const Icon(Icons.email_outlined),
                  title: 'E-mail',
                  value: _ownerEmail,
                  onTap: () => _copy(context, 'E-mail', _ownerEmail),
                  onLongPress: () => _copy(context, 'E-mail', _ownerEmail),
                ),
                const Divider(height: 1),

                // Téléphone cliquable + long-press copier
                _LinkTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: 'Téléphone',
                  value: _ownerPhone,
                  onTap: () => _launch(
                    _phoneUri,
                    labelOnError: 'Impossible d’ouvrir l’app Téléphone',
                    copyOnFail: _ownerPhone,
                  ),
                  onLongPress: () => _copy(context, 'Téléphone', _ownerPhone),
                ),
                const Divider(height: 1),

                // Site cliquable + long-press copier
                _LinkTile(
                  leading: const Icon(Icons.public),
                  title: 'Site web',
                  value: _ownerWebsite,
                  onTap: () => _launch(
                    _websiteUri,
                    labelOnError: 'Impossible d’ouvrir le navigateur',
                    copyOnFail: _ownerWebsite,
                  ),
                  onLongPress: () => _copy(context, 'Site web', _ownerWebsite),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legal / Credits
          _Section(title: 'Légal & Crédits'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                '© ${DateTime.now().year} — Tous droits réservés.\n'
                'Ce logiciel est fourni en l’état, sans aucune garantie explicite ou implicite.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme.titleSmall;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: ts),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LinkTile({
    required this.leading,
    required this.title,
    required this.value,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.solid,
    );

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: Text(value, style: linkStyle),
        trailing: const Icon(Icons.open_in_new_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
