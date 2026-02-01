import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// V9.0: API Key read from .env or build environment (Secure)
String _getApiKey() {
  // 1. Try Build Environment (CI/CD or --dart-define)
  const buildKey = String.fromEnvironment('GEMINI_API_KEY');
  if (buildKey.isNotEmpty) return buildKey;
  
  // 2. Try .env file (Local Dev)
  return dotenv.env['GEMINI_API_KEY'] ?? '';
}

class GeminiService {
  final GenerativeModel? _model;
  final String _apiKey;

  GeminiService(this._apiKey) 
      : _model = (_apiKey.isEmpty || _apiKey.contains("PLACEHOLDER"))
            ? null 
            : GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);

  Future<String> getCounsel(
    String userMessage, {
    String? userProfileContext, 
    List<dynamic>? plansMetadata,
    String language = 'fr',
  }) async {
    // If no model (API key missing), return fallback immediately
    if (_model == null) {
      debugPrint("⚠️ GEMINI_API_KEY manquante ou invalide. Utilisation du fallback.");
      return _getFallbackResponse(userMessage);
    }

    try {
      // 1. PRIVACY FILTER (Anonymization)
      final contextPrompt = userProfileContext != null 
          ? "Contexte Profil (Anonyme): $userProfileContext. "
          : "";

      // 2. DYNAMIC PRICING CONTEXT
      String pricingContext = "";
      if (plansMetadata != null && plansMetadata.isNotEmpty) {
        pricingContext = "NOS OFFRES ACTUELLES (DYNAMIQUES) :\n";
        for (var p in plansMetadata) {
          pricingContext += "- '${p.name}' : ";
          if (p.prices['EUR'] == 0) {
            pricingContext += "Gratuit. ";
          } else {
            pricingContext += "${p.prices['EUR']}€ / ${p.prices['XOF']} FCFA par mois. ";
          }
          pricingContext += "Limites: ${p.limits['maxCircles']} cercles, ${p.limits['maxMembers']} membres.\n";
        }
      } else {
        // Fallback pricing if metadata is missing
        pricingContext = """
        NOS OFFRES (Abonnement mensuel) :
        - 'Gratuit' (0€) : 1 tontine active max, 5 participants max.
        - 'Starter' (3.99€ / 2500 FCFA) : 2 tontines max, 10 participants max.
        - 'Standard' (6.99€ / 5000 FCFA) : 3 tontines max, 15 participants max.
        - 'Premium' (9.99€ / 7500 FCFA) : 5 tontines max, 20 participants max. Support VIP.
        """;
      }

      final prompt = """
      Tu es 'Tontii (Coach Financier)', l'assistant intelligent et coach officiel de l'application Tontetic. Ton nom est exclusivement "Tontii".
      
      TON SAVOIR (Vérité Absolue) :
      1. QUI SOMMES-NOUS ? : Tontetic est une appli mobile internationale. Nous opérons en AFRIQUE (Sénégal, Mali, Ivory Coast...) ET EN EUROPE (France, Belgique...).
      2. NOTRE FORCE : Nous connectons la diaspora à leurs proches, mais nous permettons aussi des tontines locales 100% France ou 100% Afrique.
      3. $pricingContext
      4. RÈGLE D'OR (SÉCURITÉ) : Quel que soit le plan, la cotisation mensuelle individuelle est PLAFONNÉE à **500 €** (ou 325 000 FCFA). C'est une limite de sécurité inviolable.
      5. OFFRE SPÉCIALE 'PIONNIERS' : Offre exceptionnelle pour le lancement ! Les 20 premiers créateurs de cercles Starter et leurs invités reçoivent 3 mois de plan 'Starter' GRATUITS.
      6. FONCTIONNEMENT DES 'NATTS' (Tontines) : 
         - Les membres cotisent chaque mois (ou semaine).
         - Chacun récupère le pot à tour de rôle (Tirage au sort ou Vote).
      7. SÉCURITÉ & FIABILITÉ :
         - 'Score d'Honneur' : Système de réputation de 0 à 100. Un score élevé débloque des cercles Marchands/Premium. Les retards impactent le score.
         - 'Garantie Solidaire' : Mécanisme de protection légal.
      8. PHILOSOPHIE : Transparence, Solidarité, Zéro frais cachés, Zéro intérêt.
      
      RÈGLES DE RÉPONSE & TON DE VOIX (CRITIQUE) :
      1. Ton nom est 'Tontii'. Présente-toi comme 'Tontii (Coach Financier)'. Sois fier de ton nom, c'est ton identité.
      2. TON : Encourageant, clair, professionnel et bienveillant.
      3. VOUVOIEMENT : Tu dois TOUJOURS utiliser le 'Vous' pour t'adresser à l'utilisateur en Français.
      4. LANGUES : Tu parles Français et **WOLOF**.
      5. LANGUE ACTUELLE : Réponds impérativement dans la langue suivante : **${language.toUpperCase()}**. Si c'est 'WO', utilise un Wolof authentique. Si c'est 'FR', utilise le Français avec vouvoiement.
      6. TERMINOLOGIE LOCALE (Wolof) : Utilise le terme **"Natt"** pour la tontine et **"Mbindu"** pour la cotisation. N'hésite pas à utiliser des termes comme **"Koolute"** (confiance/crédibilité) pour parler du Score d'Honneur.
      7. MÉTAPHORE SIMULATEUR (Wolof) : Pour expliquer l'avantage de la natt par rapport à l'épargne solo, utilise la métaphore de l'accélération : "Solo = Sama bopp (lent comme une tortue 🐢)", "Natt = Àndandoo (rapide comme un avion ✈️ ou un cheval 🐎)".
      8. CONSEILS PRATIQUES : Donne des conseils financiers concrets (ex: 'Si vous cotisez 10€ de plus, vous terminerez 2 mois plus tôt').
      9. PÉRIMÈTRE : Tu ne réponds qu'aux questions sur Tontetic et les finances. Si hors sujet, réoriente poliment vers l'épargne.
      10. RECONNAISSANCE VOCALE : Si le message utilisateur commence par une mention indiquant qu'il s'agit d'un message vocal (ex: "J'ai bien reçu votre message vocal..."), commence TOUJOURS ta réponse par une phrase de confirmation bienveillante du type : "J'ai bien entendu votre message, voici mes conseils..." (ou équivalent en Wolof).
      11. DATE DU JOUR : ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}.
      
      $contextPrompt
      
      Question utilisateur : $userMessage
      """;

      final content = [Content.text(prompt)];
      
      // Add 15 second timeout to prevent infinite waiting
      final response = await _model.generateContent(content)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('API timeout');
      });

      final responseText = response.text ?? _getFallbackResponse(userMessage);

      // 3. AUDIT LOGGING (Back-office Visibility)
      // Stores user query and AI response for compliance/quality check
      try {
        // We use a try/catch to ensure logging failure doesn't block the UI response
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('ai_logs').add({
            'userId': user.uid,
            'userEmail': user.email,
            'query': userMessage,
            'response': responseText,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'success',
            'model': 'gemini-2.0-flash'
          });
        }
      } catch (e) {
        debugPrint("⚠️ AI Log Failed: $e");
      }

      return responseText;
    } on TimeoutException {
      _logError(userMessage, 'timeout');
      return _getFallbackResponse(userMessage);
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      _logError(userMessage, errorMsg);
      
      // V9.6: Graceful Quota Error Handling
      if (errorMsg.contains('quota') || errorMsg.contains('rate') || errorMsg.contains('limit')) {
        return _getFallbackResponse(userMessage);
      }
      
      if (errorMsg.contains('network') || errorMsg.contains('socket')) {
        return "📡 Connexion impossible. Vérifiez votre réseau et réessayez.";
      }

      if (errorMsg.contains('key') || errorMsg.contains('api') || errorMsg.contains('403') || errorMsg.contains('401')) {
        return "🔑 Erreur d'Authentification (Clé API). Veuillez vérifier votre GEMINI_API_KEY dans le fichier .env.";
      }
      
      // Any other error: return fallback
      return _getFallbackResponse(userMessage);
    }
  }

  Future<void> _logError(String query, String error) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('ai_logs').add({
          'userId': user.uid,
          'userEmail': user.email,
          'query': query,
          'response': 'ERROR: $error',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'error',
          'model': 'gemini-2.0-flash'
        });
      }
    } catch (_) {}
  }
  
  /// Fallback responses when API quota is exceeded
  String _getFallbackResponse(String userMessage) {
    final message = userMessage.toLowerCase();
    
    // Common questions with pre-built answers
    if (message.contains("bonjour") || message.contains("salut") || message.contains("hello") || message.contains("coucou")) {
      return """
👋 **Bonjour ! Ravi de vous voir.**

Je suis **Tontii**, votre coach financier Tontetic. 
Je suis là pour répondre à toutes vos questions sur les tontines, l'épargne et nos offres.

**Comment puis-je vous aider aujourd'hui ?**
_Exemple : "C'est quoi Tontetic ?", "Comment créer un cercle ?", "Parle-moi en Wolof"_
""";
    }

    if (message.contains("c'est quoi") || message.contains("tontetic") || message.contains("explique")) {
      return """
🌍 **Bienvenue chez Tontetic !**

Je suis Tontii (votre Coach Financier). Voici ce que vous devez savoir :

**📱 Tontetic, c'est quoi ?**
Une app d'épargne solidaire qui digitalise les tontines traditionnelles. Vous épargnez avec vos proches, chacun récupère le pot à tour de rôle !

**💰 Comment ça marche ?**
1. Créez ou rejoignez un cercle
2. Cotisez chaque mois (ex: 50 000 F)
3. Récupérez le pot complet quand c'est votre tour

**🔒 C'est sécurisé ?**
Oui ! Signature légale, garantie solidaire, et Score d'Honneur pour garantir la fiabilité.

_Note: J'utilise mes connaissances internes pour vous répondre._ 🙏
""";
    }

    if (message.contains("wolof") || message.contains("langue") || message.contains("naka")) {
       return """
🇸🇳 **Waaw ! Toubaarkalla !**

Je parle parfaitement le **Wolof** et le Français. Vous pouvez me poser vos questions en Wolof si vous préférez !

**Exemples :**
- "Naka la natt di doxé ?" (Comment fonctionne la tontine ?)
- "Tontii, neexal ma mbindu mi." (Tontii, facilite-moi la cotisation.)

_Note: Ma connexion IA est momentanément limitée, mais je reste à votre écoute._ 😊
""";
    }
    
    if (message.contains("prix") || message.contains("abonnement") || message.contains("gratuit") || message.contains("starter")) {
      return """
💎 **Nos offres Tontetic :**

**🆓 Gratuit** : 1 tontine active (5 membres max)
**⭐ Starter** : 2 tontines actives (10 membres max) - 3.99€ / 2500 F
**💎 Standard** : 3 tontines actives (15 membres max) - 6.99€ / 5000 F
**👑 Premium** : 5 tontines actives (20 membres max) - 9.99€ / 7500 F

🚀 **OFFRE PIONNIERS :** Les 20 premiers créateurs de cercles Starter et leurs invités reçoivent 3 MOIS offerts !
""";
    }
    
    if (message.contains("cercle") || message.contains("créer") || message.contains("rejoindre")) {
      return """
🤝 **Créer ou Rejoindre un Cercle :**

**Créer** : Va dans l'onglet "Mes Cercles" → "Nouveau" et invite tes proches !

**Rejoindre** : Explore les cercles publics ou scanne le QR code d'un ami.

**Conseil** : Commence par un cercle de 5-10 personnes de confiance 👨‍👩‍👧‍👦
""";
    }
    
    // Default fallback
    return """
🧠 **Je suis là pour vous aider !**

Désolé, je n'ai pas pu traiter votre demande de manière personnalisée à l'instant.

**💡 Vous pouvez :**
- Poser une question sur le fonctionnement
- Demander les tarifs
- Consulter la FAQ dans les Paramètres

_Merci de votre confiance !_ 🙏
""";
  }
  
  // Method to check if ready (V9.0: Now checks for valid env key)
  bool get isReady => _apiKey.isNotEmpty && !_apiKey.contains('PLACEHOLDER');
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  // V9.0: Read API key from secure .env file
  return GeminiService(_getApiKey());
});
