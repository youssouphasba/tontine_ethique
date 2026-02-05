// Utilitaires de validation pour les formulaires
// Conformité RGPD, sécurité et UX

class Validators {
  Validators._();

  // ========== EMAIL VALIDATION (RFC 5322) ==========

  /// Regex RFC 5322 simplifiée pour validation email
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  /// Valide un email selon RFC 5322
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email requis';
    }

    final trimmed = value.trim().toLowerCase();

    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Format d\'email invalide';
    }

    // Vérification TLD minimum
    final parts = trimmed.split('@');
    if (parts.length != 2) return 'Format d\'email invalide';

    final domain = parts[1];
    if (!domain.contains('.')) {
      return 'Domaine email invalide';
    }

    final tld = domain.split('.').last;
    if (tld.length < 2) {
      return 'Extension de domaine invalide';
    }

    return null;
  }

  // ========== PHONE VALIDATION (E.164) ==========

  /// Valide un numéro de téléphone (partie locale sans code pays)
  static String? validatePhoneLocal(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro de téléphone requis';
    }

    // Nettoyer le numéro (retirer espaces, tirets, parenthèses)
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Retirer le 0 initial si présent
    final normalized = cleaned.startsWith('0') ? cleaned.substring(1) : cleaned;

    // Vérifier que c'est uniquement des chiffres
    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return 'Le numéro ne doit contenir que des chiffres';
    }

    // Vérifier la longueur (6-14 chiffres pour la partie locale)
    if (normalized.length < 6) {
      return 'Numéro trop court (minimum 6 chiffres)';
    }
    if (normalized.length > 14) {
      return 'Numéro trop long (maximum 14 chiffres)';
    }

    return null;
  }

  /// Valide un numéro complet E.164 (avec code pays)
  static String? validatePhoneE164(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro de téléphone requis';
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (!cleaned.startsWith('+')) {
      return 'Le numéro doit commencer par + (code pays)';
    }

    // E.164: maximum 15 chiffres au total (incluant code pays sans le +)
    final digits = cleaned.substring(1);
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
      return 'Format invalide';
    }

    if (digits.length < 8 || digits.length > 15) {
      return 'Longueur de numéro E.164 invalide';
    }

    return null;
  }

  // ========== PASSWORD VALIDATION ==========

  /// Exigences minimales pour le mot de passe (NIST 2024)
  static const int minPasswordLength = 12;

  /// Liste de mots de passe courants à bloquer
  static final Set<String> _commonPasswords = {
    'password', 'password1', 'password123', '123456', '12345678', '123456789',
    'qwerty', 'azerty', 'abc123', 'letmein', 'welcome', 'admin', 'login',
    'passw0rd', 'master', 'hello', 'charlie', 'donald', 'football', 'shadow',
    'sunshine', 'princess', 'monkey', 'dragon', 'iloveyou', 'trustno1',
    'tontine', 'tontetic', 'motdepasse', 'bienvenue',
  };

  /// Valide la force du mot de passe
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }

    if (value.length < minPasswordLength) {
      return 'Minimum $minPasswordLength caractères';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Au moins une majuscule requise';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Au moins une minuscule requise';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Au moins un chiffre requis';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\[\]\\;~/`]').hasMatch(value)) {
      return 'Au moins un caractère spécial requis (!@#\$%^&*...)';
    }

    // Vérifier les mots de passe courants
    if (_commonPasswords.contains(value.toLowerCase())) {
      return 'Ce mot de passe est trop courant';
    }

    return null;
  }

  /// Valide la confirmation du mot de passe
  static String? validatePasswordConfirm(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirmation requise';
    }
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  /// Calcule la force du mot de passe (0-5)
  static int passwordStrength(String password) {
    int strength = 0;

    if (password.length >= 12) strength++;
    if (password.length >= 16) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\[\]\\;~/`]').hasMatch(password)) strength++;

    // Pénalité pour patterns communs
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) strength--; // Répétitions (aaa, 111)
    if (RegExp(r'(012|123|234|345|456|567|678|789|890)').hasMatch(password)) strength--;
    if (RegExp(r'(abc|bcd|cde|def|efg)').hasMatch(password.toLowerCase())) strength--;

    return strength.clamp(0, 5);
  }

  // ========== DATE OF BIRTH VALIDATION (RGPD Art. 8) ==========

  /// Âge minimum requis (RGPD France = 15 ans, défaut UE = 16 ans)
  static const int minAge = 16;
  static const int maxAge = 120;

  /// Parse une date au format JJ/MM/AAAA
  static DateTime? parseDate(String value) {
    try {
      final parts = value.split('/');
      if (parts.length != 3) return null;

      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day == null || month == null || year == null) return null;
      if (day < 1 || day > 31) return null;
      if (month < 1 || month > 12) return null;
      if (year < 1900 || year > DateTime.now().year) return null;

      final date = DateTime(year, month, day);

      // Vérifier que la date est valide (pas 31 février par ex.)
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  /// Calcule l'âge à partir d'une date de naissance
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  /// Valide une date de naissance
  static String? validateBirthDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date de naissance requise';
    }

    final date = parseDate(value);
    if (date == null) {
      return 'Format invalide (JJ/MM/AAAA)';
    }

    if (date.isAfter(DateTime.now())) {
      return 'La date ne peut pas être dans le futur';
    }

    final age = calculateAge(date);

    if (age < minAge) {
      return 'Vous devez avoir au moins $minAge ans (RGPD)';
    }

    if (age > maxAge) {
      return 'Date de naissance invalide';
    }

    return null;
  }

  // ========== SIRET/NIF VALIDATION ==========

  /// Valide un numéro SIRET français (14 chiffres + clé Luhn)
  static String? validateSiret(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro SIRET requis';
    }

    final cleaned = value.replaceAll(RegExp(r'\s'), '');

    if (!RegExp(r'^[0-9]{14}$').hasMatch(cleaned)) {
      return 'Le SIRET doit contenir 14 chiffres';
    }

    // Vérification de la clé de contrôle (algorithme de Luhn)
    if (!_validateLuhn(cleaned)) {
      return 'Numéro SIRET invalide (clé de contrôle incorrecte)';
    }

    return null;
  }

  /// Valide un NIF (Numéro d'Identification Fiscale) générique
  static String? validateNif(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro d\'identification fiscale requis';
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');

    // NIF minimum 8 caractères
    if (cleaned.length < 8) {
      return 'Numéro trop court (minimum 8 caractères)';
    }

    if (cleaned.length > 20) {
      return 'Numéro trop long';
    }

    // Doit contenir principalement des chiffres
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(cleaned.toUpperCase())) {
      return 'Format invalide';
    }

    return null;
  }

  /// Algorithme de Luhn pour validation SIRET/SIREN
  static bool _validateLuhn(String number) {
    int sum = 0;
    bool alternate = false;

    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  // ========== OTP VALIDATION ==========

  /// Valide un code OTP (6 chiffres)
  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Code requis';
    }

    final cleaned = value.trim();

    if (cleaned.length != 6) {
      return 'Le code doit contenir 6 chiffres';
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(cleaned)) {
      return 'Le code ne doit contenir que des chiffres';
    }

    return null;
  }

  // ========== NAME VALIDATION ==========

  /// Valide un prénom ou nom
  static String? validateName(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return '$fieldName doit contenir au moins 2 caractères';
    }

    if (trimmed.length > 50) {
      return '$fieldName est trop long (max 50 caractères)';
    }

    // Autoriser lettres, espaces, tirets, apostrophes
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s\-']+$").hasMatch(trimmed)) {
      return '$fieldName contient des caractères non autorisés';
    }

    return null;
  }
}
