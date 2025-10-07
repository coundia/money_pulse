import 'package:flutter/material.dart';

class ProductInfoCompact extends StatelessWidget {
  final String name;

  /// Chaîne déjà formatée (ex: "5 000 FCFA"). Utilisée pour l'affichage.
  /// Si vous fournissez aussi [priceXof], c'est [priceXof] qui décide
  /// si le bloc prix doit être affiché (>1), puis on affiche [priceStr].
  final String priceStr;

  /// Valeur numérique du prix en XOF (facultatif).
  /// Si présent, le prix n'est affiché que si `priceXof > 1`.
  /// Si absent, on conserve l'ancien comportement (afficher si `priceStr` non vide).
  final int? priceXof;

  final String? description;
  final ThemeData theme;

  /// Affiche une petite mention d'indisponibilité
  final bool showOutOfStockNotice;

  const ProductInfoCompact({
    super.key,
    required this.name,
    required this.priceStr,
    required this.theme,
    this.priceXof,
    this.description,
    this.showOutOfStockNotice = false,
  });

  @override
  Widget build(BuildContext context) {
    // Règle d'affichage du prix:
    // - si priceXof est fourni: afficher uniquement si > 1
    // - sinon: fallback à "priceStr non vide"
    final bool shouldShowPrice = (priceXof != null)
        ? (priceXof! > 100)
        : priceStr.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2, top: 2, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),

            // (Optionnel) info indisponible
            if (showOutOfStockNotice) ...[
              const SizedBox(height: 4),
              Text(
                'Actuellement indisponible',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ],

            // Prix (uniquement si > 1 quand priceXof est fourni)
            if (shouldShowPrice) ...[
              const SizedBox(height: 4),
              Text(
                priceStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],

            // Description (optionnelle)
            if ((description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
