Splash natif avec flutter_native_splash pour éviter le “blank frame”.

pubspec.yaml → ajoute flutter_native_splash.

Image simple et couleurs unies, pas de SVG lourd.

Pas de gros travaux sync avant runApp : toute I/O dans le provider.

Pré-cache des assets critiques dans le home après navigation, pas avant.

Limiter les rebuilds dans le gate; on écoute l’AsyncValue et on navigue une seule fois.