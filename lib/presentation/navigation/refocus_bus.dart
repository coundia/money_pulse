/// Un petit bus global, ultra simple, pour signaler au prochain écran
/// depuis quelle page on revient. On pose un "tag" au moment du pop,
/// et l’écran courant peut décider de rafraîchir seulement si le tag match.
///
/// Exemple d’usage :
///   RefocusBus.mark('chatbot');   // avant de pop ChatbotPage
///   final tag = RefocusBus.take(); // sur la page cible (consomme la valeur)
class RefocusBus {
  static String? _lastTag;

  /// Pose un tag (ex: 'chatbot') juste avant de quitter une page.
  static void mark(String tag) => _lastTag = tag;

  /// Récupère et efface le tag.
  static String? take() {
    final t = _lastTag;
    _lastTag = null;
    return t;
  }
}
