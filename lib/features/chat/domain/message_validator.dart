class MessageValidator {
  // Regex pour détecter les emails
  static final RegExp _emailRegex = RegExp(
    r"[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  // Regex simplifiée pour détecter les numéros de téléphone (formats courants)
  // Détecte les séquences de 9 chiffres ou plus, avec ou sans séparateurs
  static final RegExp _phoneRegex = RegExp(
    r"\+?(\d[\s-]?){9,}",
  );

  static String? validateMessage(String message) {
    if (_emailRegex.hasMatch(message)) {
      return 'Pour votre sécurité, le partage d\'adresses email est interdit dans le chat.';
    }

    if (_phoneRegex.hasMatch(message)) {
      return 'Pour votre sécurité, le partage de numéros de téléphone est interdit dans le chat.';
    }

    return null; // Le message est valide
  }
}
