// File: lib/presentation/features/settings/about_page.dart
// À propos — jaayKo : header premium, logo/initiales "JK" avec anneau dégradé,
// actions rapides, fallback robuste, liens cliquables.

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

  bool _assetOk = true; // on suppose présent, on dégrade si échec

  // === Infos jaayKo ===
  static const String _appName = 'JaayKo';
  static const String _version = '1.0.0';
  static const String _ownerName = 'Papa COUNDIA';
  static const String _ownerEmail = 'contact@pcoundia.com';
  static const String _ownerPhone = '+221 77 539 24 82';
  static const String _ownerWebsite = 'https://pcoundia.com';
  static const String _shortDesc =
      'Permet de vendre et gérer ton business — simple, rapide et sécurisé.';

  Uri get _phoneUri {
    final digits = _ownerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    return Uri(scheme: 'tel', path: digits);
  }

  Uri get _emailUri => Uri(
    scheme: 'mailto',
    path: _ownerEmail,
    queryParameters: {'subject': 'Contact depuis jaayKo'},
  );

  Uri get _websiteUri => Uri.parse(_ownerWebsite);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Précharger le logo; si indispo -> fallback
    precacheImage(const AssetImage(_assetPath), context).catchError((e, st) {
      if (kDebugMode) {
        debugPrint(
          '[AboutPage] Asset not found: $_assetPath\n'
          'Vérifie pubspec.yaml et le chemin de l’image, puis: '
          'flutter clean && flutter pub get',
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

  // ---------- UI Helpers ----------

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(.12), cs.tertiary.withOpacity(.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          _LogoBadge(assetOk: _assetOk, size: 96, assetPath: _assetPath),
          const SizedBox(height: 12),
          Text(
            _appName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _shortDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _QuickAction(
                icon: Icons.phone_rounded,
                label: 'Appeler',
                onTap: () => _launch(
                  _phoneUri,
                  labelOnError: 'Impossible d’ouvrir Téléphone',
                  copyOnFail: _ownerPhone,
                ),
              ),
              _QuickAction(
                icon: Icons.email_rounded,
                label: 'E-mail',
                onTap: () => _launch(
                  _emailUri,
                  labelOnError: 'Impossible d’ouvrir l’e-mail',
                  copyOnFail: _ownerEmail,
                ),
              ),
              _QuickAction(
                icon: Icons.public_rounded,
                label: 'Site',
                onTap: () => _launch(
                  _websiteUri,
                  labelOnError: 'Impossible d’ouvrir le navigateur',
                  copyOnFail: _ownerWebsite,
                ),
              ),
              _QuickAction(
                icon: Icons.copy_rounded,
                label: 'Copier',
                onTap: () => _copy(
                  context,
                  'Contacts',
                  '''
$_ownerName
$_ownerEmail
$_ownerPhone
$_ownerWebsite
'''
                      .trim(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Chip(
            label: Text('Version $_version'),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: cs.surface,
          ),
        ],
      ),
    );
  }

  Widget _ownerCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Éditeur',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Nom'),
            subtitle: Text(_ownerName),
          ),
          const Divider(height: 1),
          _LinkTile(
            leading: const Icon(Icons.email_outlined),
            title: 'E-mail',
            value: _ownerEmail,
            onTap: () => _copy(context, 'E-mail', _ownerEmail),
            onLongPress: () => _copy(context, 'E-mail', _ownerEmail),
          ),
          const Divider(height: 1),
          _LinkTile(
            leading: const Icon(Icons.phone_outlined),
            title: 'Téléphone',
            value: _ownerPhone,
            onTap: () => _launch(
              _phoneUri,
              labelOnError: 'Impossible d’ouvrir Téléphone',
              copyOnFail: _ownerPhone,
            ),
            onLongPress: () => _copy(context, 'Téléphone', _ownerPhone),
          ),
          const Divider(height: 1),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vos données restent sur votre appareil sauf si vous activez explicitement la synchronisation.',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Légal & Crédits',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _ownerCard(context),
                const SizedBox(height: 16),
                _legalCard(context),
                const SizedBox(height: 24),
                // Petit crédit discret
                Opacity(
                  opacity: .75,
                  child: Text(
                    'Made with ❤️',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Components ----------------

class _LogoBadge extends StatelessWidget {
  final bool assetOk;
  final double size;
  final String assetPath;
  const _LogoBadge({
    required this.assetOk,
    required this.size,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Anneau dégradé autour du logo/initiales
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [cs.primary, cs.tertiary, cs.primary],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3), // épaisseur de l’anneau
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface),
        clipBehavior: Clip.antiAlias,
        child: assetOk
            ? _AnimatedLogo(assetPath: assetPath)
            : const _InitialsFallback(),
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  final String assetPath;
  const _AnimatedLogo({required this.assetPath});
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      frameBuilder: (context, child, frame, _) {
        if (frame == null) {
          return const SizedBox.expand(); // évite le pop-in
        }
        return AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 250),
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => const _InitialsFallback(),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceVariant.withOpacity(.35),
      alignment: Alignment.center,
      child: Text(
        'JK', // Initiales jaayKo
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.tonalIcon(
      icon: Icon(icon),
      label: Text(label),
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll<Color>(cs.onTertiaryContainer),
      ),
      onPressed: onTap,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [Text(title, style: titleStyle)]),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
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
