# Claude Context - Tontine Éthique (Tontetic)

> **IMPORTANT** : À chaque nouvelle session, lire ce fichier en premier avec `Read claude_context.md`

**Dernière mise à jour** : 2026-02-05
**Session précédente** : P2/P3 Code Quality (Dependencies + TODOs cleanup)

---

## 1. ÉTAT ACTUEL DU PROJET

### Description
Application Flutter de tontines communautaires (épargne rotative) avec:
- App mobile (Android/iOS) + Web
- Admin backoffice (Flutter Web)
- Backend Firebase (Firestore, Cloud Functions, Auth, Storage)
- Paiements Stripe (Connect pour créateurs, Checkout pour abonnements)

### Stack technique
- **Frontend** : Flutter 3.x, Riverpod, GoRouter
- **Backend** : Firebase (Firestore, Functions, Auth, FCM)
- **Paiements Tontines** : Mangopay (Wallets + SEPA DD/CT) - EN COURS
- **Paiements Abonnements** : Stripe (Checkout Sessions)
- **KYC** : Mangopay (basique) + Stripe Identity (avancé)
- **IA** : Google Gemini (coach financier)

### Structure des fichiers clés
```
lib/
├── main.dart                 # Entry point app mobile
├── main_backoffice.dart      # Entry point admin
├── core/
│   ├── models/               # UserState, TontineModel, etc.
│   ├── providers/            # Riverpod providers
│   ├── services/             # Stripe, Auth, Circle, etc.
│   ├── routing/router.dart   # GoRouter config
│   └── theme/app_theme.dart  # Thème UI
├── features/
│   ├── auth/                 # Login, Register, OTP
│   ├── tontine/              # Cercles, création, chat
│   ├── payments/             # Stripe, SEPA, garanties
│   ├── subscription/         # Plans (gratuit, premium, etc.)
│   └── admin/                # Backoffice screens
functions/
├── index.js                  # Cloud Functions Stripe
firestore.rules               # Règles sécurité Firestore
```

---

## 2. CE QUI FONCTIONNE ✅

### Authentification
- [x] Email/Password Firebase Auth
- [x] Google Sign-In
- [x] Phone OTP (configuration Firebase)
- [x] Vérification email obligatoire (RGPD)
- [x] Mode invité

### Paiements Stripe
- [x] Checkout Sessions (abonnements)
- [x] PaymentIntent (paiements uniques)
- [x] Stripe Connect Express (comptes créateurs)
- [x] SetupIntent SEPA (mandats prélèvement)
- [x] Cloud Functions sécurisées (secret key côté serveur)
- [x] Webhooks complets : checkout.session.completed, subscription.updated/deleted, invoice.payment_failed ✅ 2026-02-05

### Backoffice Admin (Red List Fixes) ✅ 2026-02-06
- [x] **Utilisateurs** : Recherche, Filtre (Actif/Suspendu), Export CSV (1000 items)
- [x] **Audit** : Export Juridique (ACPR), Export Actions Admin (CSV), Logs immuables
- [x] **Modération** : Inspection Contenu (Dialog), Ignore Report, Suspension
- [x] **Arbitrage** : "True Ban" (Batch write: User + Shop + Content + Score)
- [x] **Sections** : Dashboard (16 sections), Plans (Enterprise seed), Campagnes (Targeting), Parrainage_v2

### Tontines (Cercles)
- [x] Création de cercle avec paramètres
- [x] Invitations par lien/QR code
- [x] Demandes d'adhésion avec approbation
- [x] Chat de groupe E2E chiffré (AES-256-CBC + HMAC) ✅ 2026-02-05
- [x] Système de vote pour ordre de paiement
- [x] Chiffrement URLs médias (audio, images, fichiers)

### Firestore
- [x] Rules complètes (55 collections couvertes) ✅ 2026-02-05
- [x] Protection transactions (server-only write)
- [x] Audit logs
- [x] Collection e2e_keys pour distribution clés chiffrement

### UI/UX
- [x] Thème clair/sombre
- [x] Responsive (mobile + web)
- [x] Localisation FR

---

## 3. CE QUI EST CASSÉ / MANQUANT ❌

### CRITIQUES (Bloquants production)

| Problème | Fichier | Action requise |
|----------|---------|----------------|
| Clés API dans git | `.env` | `git rm --cached .env` + régénérer clés |
| ~~CORS trop ouvert~~ | ~~`functions/index.js:14`~~ | ✅ FAIT |
| ~~E2E Encryption non implémenté~~ | ~~`circle_chat_screen.dart`~~ | ✅ FAIT (2026-02-05) |
| ~~Firestore rules incomplètes~~ | ~~`firestore.rules`~~ | ✅ FAIT - 28 collections ajoutées |
| ~~Stripe webhooks manquants~~ | ~~`functions/index.js`~~ | ✅ FAIT - checkout.session.completed |
| **Intégration Mangopay** | `functions/mangopay/`, `lib/core/services/` | En attente credentials (voir §10) |
| **Absorption frais abonnés** | `subscription_provider.dart` | Flag `feesCovered` + logique paiement |

### MAJEURS (Avant lancement)

| Problème | Fichier | Status |
|----------|---------|--------|
| ~~KYC Stripe Identity~~ | ~~`identity_verification_service.dart`~~ | ✅ Implémenté |
| Wave Money | `mobile_money_service.dart` | Stub/Mock |
| Orange Money | - | Non implémenté |
| Réconciliation wallet | `wallet_reconciliation_service.dart` | Mock PSP |
| Export PDF signé | `financial_dashboard_service.dart` | Simulé |
| ~~Flux invitation complexe~~ | ~~`invitation_landing_screen.dart`~~ | ✅ Simplifié (5 → 3 étapes) |

### MINEURS (Lint issues restantes : 19 infos)

- ~~3 warnings: champs inutilisés~~ → **CORRIGÉ** (supprimés)
- ~~Unused import merchant_tab_screen.dart~~ → **CORRIGÉ** (2026-02-05)
- ~~Unused variable dashboard_screen.dart~~ → **CORRIGÉ** (2026-02-05)
- ~~Undefined getter isVerifie~~ → **CORRIGÉ** (2026-02-05)
- 15 `use_build_context_synchronously` infos (faux positifs - guards mounted corrects)
- 1 `unnecessary_import` (non bloquant)
- 1 `deprecated_member_use` (activeColor → activeThumbColor)
- 1 `use_build_context_synchronously` additionnel
- ~~7 TODOs~~ → **CORRIGÉ** (2026-02-05) - Convertis en notes/implémentés
- ~~4 `print()` dans `tools/set_admin.dart`~~ → **CORRIGÉ** (ignore comments)
- ~~6 `withOpacity`~~ → **CORRIGÉ**
- ~~2 constantes snake_case~~ → **CORRIGÉ**
- ~~CORS `*`~~ → **CORRIGÉ** (whitelist domaines)
- ~~`unnecessary_brace_in_string_interps`~~ → **CORRIGÉ**
- ~~`unnecessary_underscores`~~ → **CORRIGÉ**
- ~~`dangling_library_doc_comments`~~ → **CORRIGÉ**

---

## 4. PROCHAINES TÂCHES (Par priorité)

### P0 - Sécurité (URGENT)
1. [x] Retirer `.env` de git → **VÉRIFIÉ** (pas tracké)
2. [x] Ajouter `.env` au `.gitignore` → **VÉRIFIÉ** (présent)
3. [ ] Régénérer TOUTES les clés API (Google, Gemini, Stripe) ⚠️ **ACTION MANUELLE**
4. [x] Restreindre CORS dans `functions/index.js` → **CORRIGÉ**

### P1 - Production-ready
5. [x] Implémenter KYC Stripe Identity réel → **FAIT**
6. [ ] Connecter Wave API (Sénégal)
7. [ ] Wrapper `debugPrint` avec `kReleaseMode` check
8. [x] Préparer basculement Stripe mode LIVE → **FAIT** (voir checklist ci-dessous)

### P2 - Qualité code
9. [x] Corriger les warnings lint → **FAIT** (0 errors, 0 warnings, 19 infos)
10. [x] Mettre à jour dépendances (`flutter pub upgrade`) → **FAIT** (10 packages)
11. [x] Supprimer code mort et TODOs → **FAIT** (7 TODOs nettoyés)

### P3 - Fonctionnalités
12. [x] Notifications push FCM → **FAIT** (implémenté, test manuel requis)
13. [x] Export PDF réel avec signature → **FAIT** (`pdf_export_service.dart`)
14. [ ] Dashboard analytics admin → Stub (pas de backend)

### 🔜 TODO Prochaine Session (Inscription)
- [x] Enregistrer consentement newsletter dans Firestore (`individual_registration_screen.dart`) ✅ FAIT
- [ ] Rate limiting OTP (max 3 envois / 10 min) - Planifié dans plan P1/P2
- [ ] Augmenter TTL OTP de 60s → 5 min - Planifié dans plan P1/P2
- [ ] Sauvegarde brouillon local (SharedPreferences)
- [ ] Email verification bloquante (transactions financières)
- [ ] Implémenter photo profil (Step 3) - Planifié dans plan P1/P2
- [ ] Validation IBAN réelle (company registration)
- [ ] Export consentements PDF (RGPD Art. 15)

### 🔜 TODO Intégration Mangopay (PRIORITÉ HAUTE)
- [ ] **Phase 1** : Attendre credentials Mangopay Sandbox
- [x] **Phase 2** : Cloud Functions Mangopay (users, wallets, mandates, payins, transfers, payouts) ✅ FAIT
- [x] **Phase 3** : Services Flutter (`mangopay_service.dart`, `mangopay_payment_service.dart`) ✅ FAIT
- [ ] **Phase 4** : Logique absorption frais pour abonnés
- [ ] **Phase 5** : Tests E2E flux complet
- [x] Simplifier flux invitation (5 → 3 étapes) ✅ FAIT
- [ ] Supprimer système de "balance" virtuelle (risque PSP)

---

## 5. RÈGLES À RESPECTER

### Architecture
- **Riverpod** : Utiliser `ref.watch()` pour les rebuilds, `ref.read()` pour les actions
- **GoRouter** : Navigation via `context.push()` / `context.go()`
- **Models** : Tous dans `lib/core/models/` avec `fromFirestore`/`toFirestore`

### Sécurité
- **JAMAIS** de secret keys côté client (utiliser Cloud Functions)
- **JAMAIS** de `debugPrint` avec données sensibles (email, téléphone, montants)
- **TOUJOURS** vérifier `mounted` après un `await` avant d'utiliser `context`

### Firestore
- Transactions financières : **SERVER-SIDE ONLY** (`allow write: if false`)
- Données utilisateur sensibles : protégées par `isOwner(userId)`
- Admin : via Custom Claims (`request.auth.token.admin == true`)

### Stripe (Abonnements uniquement)
- Utiliser Cloud Functions pour créer CheckoutSession
- URLs de retour : `tontetic://` (mobile) ou `https://tontetic-app.web.app/` (web)
- Toujours logger les erreurs Stripe pour debug

### Mangopay (Tontines)
- Chaque utilisateur a un Wallet Mangopay
- SEPA Direct Debit (PayIn) pour les prélèvements membres
- Transfer (Wallet → Wallet) pour consolidation
- SEPA Credit Transfer (PayOut) pour payout bénéficiaire
- Webhooks : `PAYIN_NORMAL_SUCCEEDED`, `TRANSFER_NORMAL_SUCCEEDED`, `PAYOUT_NORMAL_SUCCEEDED`
- **Absorption frais** : Vérifier `user.subscription.feesCovered` avant facturation
- **KYC** : `KYC_SUCCEEDED` requis pour PayOut > 150€

### Code style
- Pas de `print()` → utiliser `debugPrint()` wrappé avec `kReleaseMode`
- Pas de variables inutilisées (supprimer ou prefixer avec `_`)
- Pas d'imports inutilisés

### Git
- Commits en anglais avec format : `type(scope): description`
- Ne jamais commit `.env`, `*.keystore`, credentials
- Branch `main` = production ready

---

## 6. COMMANDES UTILES

```bash
# Analyse Flutter
flutter analyze

# Build Android
flutter build apk --release

# Build Web
flutter build web --release

# Déployer Firebase Hosting
firebase deploy --only hosting

# Déployer Cloud Functions
firebase deploy --only functions

# Logs Cloud Functions
firebase functions:log
```

---

## 7. CONTACTS & RESSOURCES

- **Firebase Console** : https://console.firebase.google.com/project/tontetic-admin
- **Stripe Dashboard** : https://dashboard.stripe.com/test/
- **Mangopay Hub** : https://hub.mangopay.com (EN ATTENTE)
- **Mangopay API Docs** : https://docs.mangopay.com
- **Mangopay API Reference** : https://docs.mangopay.com/api-reference
- **App Web** : https://tontetic-app.web.app

---

## 8. HISTORIQUE DES SESSIONS

### Session 2026-02-05 (Audit Sécurité Complet)

**Audit complet de l'application** - Résultats :
- ✅ **E2E Encryption** : Messages de chat chiffrés AES-256-CBC avec HMAC intégrité
- ✅ **Firestore Rules** : 28 collections manquantes ajoutées (de 27 à 55)
- ✅ **Stripe Webhooks** : checkout.session.completed + cycle complet subscription
- ✅ **RGPD Article 22** : Explication algorithme Honor Score implémentée
- ✅ **Consentement Analytics** : Opt-in séparé ajouté (RGPD Art. 6)

**Corrections P0 (Critiques)** :
- 🔐 **Chat E2E** (`circle_chat_screen.dart`) : Messages stockés chiffrés dans Firestore
  - Clé par cercle dérivée de secret partagé (SHA-256)
  - IV aléatoire 16 bytes, HMAC pour vérification intégrité
  - URLs médias également chiffrées
  - Distribution clé via `tontines/{id}/e2e_keys/{memberId}`
- 🛡️ **Firestore Rules** (`firestore.rules`) : +28 collections protégées
  - kyc_requests, liveness_checks, merchant_kyc, admin_alerts, admin_audit_logs
  - invitations, tontine_invitations, moderation_cases, orders, employees
  - consents, legal_documents, app_config, sessions, referral_campaigns
  - notifications (root), members, e2e_keys, etc.
- 💳 **Stripe Webhooks** (`functions/index.js`) : Ajout handlers manquants
  - `checkout.session.completed` → Crée entitlement + active subscription
  - `customer.subscription.updated` → Sync changements plan
  - `customer.subscription.deleted` → Désactive entitlement
  - `invoice.payment_failed` → Alerte utilisateur

**Corrections P1 (Majeurs)** :
- 📊 **Honor Score** (`dashboard_screen.dart`, `profile_screen.dart`)
  - Dialog explicatif avec formule : Score = (Paiements réussis / Total) × 5
  - Interprétation du score (Excellent/Très bon/Bon/etc.)
- 🍪 **Analytics Consent** (`settings_screen.dart`, `consent_provider.dart`)
  - Toggle séparé pour analytics
  - Texte RGPD Art. 6 explicatif
- 👤 **Admin KYC Review** (`admin_sections.dart`, `admin_dashboard.dart`)
  - Section complète pour review KYC utilisateurs
  - Actions approve/reject avec audit log

**Fichiers modifiés** :
- `lib/features/tontine/presentation/screens/circle_chat_screen.dart` - E2E encryption
- `lib/core/services/circle_service.dart` - Key distribution
- `lib/core/services/message_encryption_service.dart` - (existant, utilisé)
- `firestore.rules` - +28 collections
- `functions/index.js` - Stripe webhooks complets
- `assets/legal/POLITIQUE_CONFIDENTIALITE.md` - RGPD Art. 22
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` - Honor Score dialog
- `lib/features/social/presentation/screens/profile_screen.dart` - Honor Score dialog
- `lib/features/settings/presentation/screens/settings_screen.dart` - Analytics consent
- `lib/core/providers/consent_provider.dart` - Analytics type
- `lib/features/admin/presentation/screens/admin_sections.dart` - KYC review section
- `lib/features/admin/presentation/screens/admin_dashboard.dart` - KYC navigation

---

### Session 2026-02-02
- Audit complet du code (flutter analyze)
- Corrigé 42 warnings/erreurs (69 → 27)
- Identifié problèmes production-readiness
- Créé ce fichier de contexte
- Corrigé : withOpacity, constantes snake_case, imports/variables, guards mounted
- **Sécurité** : CORS restreint aux domaines autorisés dans `functions/index.js`

### Session 2026-02-03
- Vérifié `.env` non tracké dans git ✅
- Vérifié `.gitignore` contient `.env` ✅
- Corrigé warnings lint (27 → 14 infos):
  - Supprimé champs inutilisés : `_emailSent`, `_emailVerified`, `_recordingPath`
  - Corrigé `unnecessary_brace_in_string_interps` dans admin_sections.dart
  - Corrigé `unnecessary_underscores` dans conversations_list_screen.dart
  - Corrigé `dangling_library_doc_comments` dans validators.dart
  - Ajouté `// ignore: avoid_print` dans tools/set_admin.dart
- Les 14 infos restantes sont des `use_build_context_synchronously` (faux positifs)
- **KYC Stripe Identity** implémenté :
  - Cloud Functions : `createIdentityVerificationSession`, `getIdentityVerificationStatus`, `stripeIdentityWebhook`
  - Service Flutter : `identity_verification_service.dart` refactorisé
  - Webhook pour traitement automatique des résultats KYC
- **Préparation mode LIVE** :
  - `.env.example` mis à jour avec instructions
  - Code auto-détecte mode via préfixe clé (pk_test vs pk_live)
- **Améliorations inscription (RGPD + UX)** :
  - ✅ Ajouté champ date de naissance obligatoire (RGPD Art. 8 - min 16 ans)
- ✅ Ajouté consentement newsletter OPTIONNEL (séparé des CGU)
  - ✅ Progress bar améliorée (LinearProgressIndicator + pourcentage)
  - ✅ Résumé légal "3 points" avant checkboxes CGU
- **Analyse architecture paiements** :
  - Comparé flux actuel (balance virtuelle) vs flux cible (non-custodial)
  - Identifié risque PSP si argent transite par comptes Tontetic
  - Recommandé : Stripe Connect + SEPA DD + `transfer_data` pour routage direct
  - Documenté tarification SEPA Instant (1% via Instant Payout Stripe)
- **Simplification flux invitation** :
  - Analysé flux actuel (5 étapes) dans `invitation_landing_screen.dart`
  - Proposé flux simplifié (3 étapes) avec notifications push
  - Étape "Attente" remplacée par notification + deep link
- **Décision architecture paiements** :
  - ~~Swan abandonné~~ : Frais mensuels production trop élevés
  - **Mangopay choisi** : 0€/mois, pay-per-use, conçu pour cagnottes
  - Comparatif coûts : Mangopay 0,31% vs Stripe 0,85-1,85%
  - Modèle : Tontetic absorbe 100% frais pour abonnés
  - Plan intégration 4 phases documenté
  - Architecture hybride : Mangopay (tontines/wallets) + Stripe (abonnements)
  - Réglementation : Tontetic = outil technique, Mangopay = EMI licencié
- **Intégration Mangopay (squelettes prêts)** :
  - ✅ Créé `lib/core/services/mangopay_service.dart` - Client API complet
  - ✅ Créé `lib/core/services/mangopay_payment_service.dart` - Orchestration paiements
  - ✅ Ajouté 10 Cloud Functions Mangopay dans `functions/index.js`
  - ✅ Mis à jour `.env.example` avec config Mangopay
  - ✅ Ajouté `node-fetch` dans `functions/package.json`
- **Simplification flux invitation (implémenté)** :
  - ✅ Réécrit `invitation_landing_screen.dart` (V15 → V16)
  - ✅ Réduit de 5 à 3 étapes : Présentation+Contrat → Connexion → Terminé
  - ✅ Étape "Attente" supprimée (notification push + deep link)
  - ✅ Montant affiché dès le début (transparence)
- **Consentement newsletter** :
  - ✅ Ajouté sauvegarde Firestore dans `_completeRegistration()`

---

### Session 2026-02-05 (Localization & Business Plan)

**Localization Fixes** :
- ✅ Corrigé erreurs `l10n` dans `circle_details_screen.dart`, `savings_screen.dart`, `profile_screen.dart`
- ✅ Ajouté clés manquantes (`join_request_subtitle`, `confirm`, `error_missing_fields`, `error_accept_cgu`) dans `localization_provider.dart`
- ✅ Nettoyé code dupliqué (`get l10n`)
- ✅ Remplacé textes hardcodés dans `profile_screen.dart`

**Documentation Updates** :
- ✅ Mis à jour **Prix** dans tous les documents (`BUSINESS_PLAN_ANNEXES.md`, `BUSINESS_PLAN.md`, `BUSINESS_PLAN_EN.md`, `PROJECT_SPECIFICATIONS.md`)
  - Starter: 2,99€
  - Standard: 4,99€
  - Premium: 6,99€
  - Marchand: 14,99€ (Unique)
- ✅ Traduit dossier onboarding Mangopay en anglais : `docs/MANGOPAY_ONBOARDING_FOLDER_EN.md`


### Session 2026-02-06 (Backoffice Access & Security)

**Accès Backoffice & Sécurité** :
- ✅ **API Keys** : Restauration `GEMINI_API_KEY` et `GOOGLE_CLOUD_API_KEY` dans `.env`
- ✅ **Admin Access** : Correction accès "Accès Non Autorisé" via Custom Claims
  - Créé fonction one-shot `setFounderAdminClaims` (v2 email-based)
  - Exécutée pour grant `admin: true` + `super_admin: true`
  - Ajouté `forceRefresh` token dans `AdminWrapper`
  - Ajouté bouton Déconnexion dans sidebar et écran unauthorized
- ✅ **Admin Login** : Amélioration gestion erreurs (`user-not-found`, `wrong-password`)
- ✅ **Déploiement** : Mise à jour Firebase Hosting (Admin) et Cloud Functions

**Corrections P0 (Critiques)** :
- 🔐 **Admin Auth** (`admin_wrapper.dart`) : 
  - Problème : `role: superAdmin` dans Firestore insuffisant (règles basées sur Auth Claims)
  - Solution : Force `user.getIdToken(true)` au login pour rafraîchir claims
  - UX : Ajout debug info (UID, Role) sur écran blocage
- 🔑 **API Keys** : Clés remises en place pour `gemini_service.dart` (Mobile App)

---

## 9. ARCHITECTURE PAIEMENTS CIBLE (Mangopay + Stripe)

### Principe fondamental
**Tontetic = Agent PSP (APSP)** - L'application agit en tant qu'intermédiaire mandaté par Mangopay (APSP). AUCUNE transaction ne doit transiter par les comptes bancaires propres de Tontetic pour respecter la licence de Mangopay.

### Décision : Mangopay (Tontines) + Stripe (Abonnements)

**Pourquoi Mangopay ?**
- Conçu pour cagnottes/crowdfunding (même logique que tontines)
- Wallets + Escrow natifs
- Licence EMI européenne (Tontetic = Agent de Paiement déclaré)
- 0€ frais mensuels (pay-per-use)
- KYC intégré
- Utilisé par Leetchi, Ulule, Lunchr

**Pourquoi garder Stripe ?**
- Meilleur UX pour abonnements récurrents
- Apple Pay / Google Pay
- Déjà intégré dans l'app
- Stripe Identity pour KYC avancé

### Modèle économique
| Type utilisateur | Qui paie les frais ? |
|------------------|---------------------|
| **Abonnés** (Premium/Pro) | Tontetic absorbe 100% des frais (modèle non-custodial) |
| **Gratuits** | Frais visibles (0,30€/prélèvement) |

### Flux cible avec Mangopay

```
┌─────────────┐    SEPA DD     ┌─────────────┐    Transfer     ┌─────────────┐   SEPA CT    ┌─────────────┐
│  Membres    │ ─────────────▶ │   Wallet    │ ──────────────▶ │   Wallet    │ ───────────▶ │    IBAN     │
│  (IBAN)     │    0,30€/mbr   │   Membre    │     Gratuit     │ Bénéficiaire│    0,10€     │ Bénéficiaire│
└─────────────┘                └─────────────┘                 └─────────────┘              └─────────────┘
      │                              │                               │
      │    Tontetic absorbe          │                               │
      │    frais si abonné           │                               │
      ▼                              ▼                               ▼
  Mandat SEPA DD           Consolidation auto              Payout J+1 à J+2
```

### Tarification Mangopay
| Opération | Coût | Délai |
|-----------|------|-------|
| SEPA Direct Debit (PayIn) | 0,30€ | J+5 (1er), J+1 (récurrent) |
| Wallet → Wallet (Transfer) | Gratuit | Instantané |
| SEPA Credit Transfer (PayOut) | 0,10€ | J+1 à J+2 |
| KYC (vérification identité) | Inclus | ~24h |

### Coût par cycle (10 membres × 100€)
| Opération | Mangopay | Stripe |
|-----------|----------|--------|
| 10× Prélèvements | 3,00€ | 8,50€ |
| Consolidation | 0€ | N/A |
| 1× Payout | 0,10€ | 0€ (J+2) |
| **Total** | **3,10€** (0,31%) | 8,50€ (0,85%) |

### Répartition PSP par fonctionnalité
| Fonctionnalité | PSP | Raison |
|----------------|-----|--------|
| **Tontines (wallets)** | Mangopay | Escrow natif via compte tiers |
| **Tontines (prélèvements)** | Mangopay | SEPA DD optimisé |
| **Tontines (payouts)** | Mangopay | Wallet → IBAN |
| **Abonnements app** | Stripe | Checkout + récurrence |
| **Paiements carte ponctuels** | Stripe | Apple/Google Pay |
| **KYC basique** | Mangopay | Inclus dans flux Agent PSP |
| **KYC avancé** | Stripe Identity | Document + Selfie |
| **Mobile Money (FCFA)** | Wave | Zone Afrique |

### Réglementation : Tontetic = Agent PSP (APSP)

```
┌─────────────────────────────────────────────────────────────────┐
│                         TONTETIC                                │
│                   (Agent de Paiement)                           │
│                                                                 │
│  ✅ Gestion cercles    ✅ Règles tontine    ✅ Notifications   │
│  ✅ Orchestration API  ✅ Dashboard         ✅ Abonnements     │
│                                                                 │
│         DÉCLARÉ À L'ACPR COMME AGENT DE MANGOPAY                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ API calls (mandatés)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         MANGOPAY                                │
│                 (Établissement Monnaie Électronique)            │
│                                                                 │
│  💰 Wallets utilisateurs    💳 SEPA DD/CT    🔐 KYC            │
│  💸 Escrow/Séquestre        📋 Conformité    🏦 Licence EMI    │
│                                                                 │
│              Agréé ACPR + Responsable du mandat                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. ARCHITECTURE CHIFFREMENT E2E (Messages)

### Principe
Les messages du chat de cercle sont chiffrés **avant** d'être envoyés à Firestore. Même avec un accès admin Firebase, les messages sont illisibles.

### Algorithmes utilisés
- **AES-256-CBC** : Chiffrement symétrique des messages
- **HMAC-SHA256** : Vérification intégrité (anti-tampering)
- **SHA-256** : Dérivation de clé depuis secret partagé

### Structure données Firestore
```
tontines/{circleId}/messages/{messageId}
├── senderId: "uid"
├── senderName: "Nom" (non chiffré pour affichage)
├── type: "text" | "image" | "audio" | "file"
├── isEncrypted: true
├── encrypted: {              // Pour messages texte
│   ├── ciphertext: "base64..."
│   ├── iv: "base64..."
│   ├── hmac: "sha256..."
│   └── version: 1
│   }
├── encryptedUrl: { ... }     // Pour médias (URL chiffrée)
└── timestamp: ServerTimestamp

tontines/{circleId}/e2e_keys/{memberId}
├── encryptedSecret: "AES encrypted circle secret"
├── createdAt: Timestamp
└── version: 1
```

### Flux de chiffrement
```
┌─────────────────┐    Clé cercle     ┌──────────────────┐
│  Message texte  │ ────────────────▶ │  AES-256-CBC     │
│  "Bonjour!"     │                   │  + IV aléatoire  │
└─────────────────┘                   └────────┬─────────┘
                                               │
                                               ▼
                                      ┌──────────────────┐
                                      │  HMAC-SHA256     │
                                      │  (intégrité)     │
                                      └────────┬─────────┘
                                               │
                                               ▼
                                      ┌──────────────────┐
                                      │  Firestore       │
                                      │  (chiffré)       │
                                      └──────────────────┘
```

### Distribution des clés
1. **Création cercle** : Génération secret aléatoire (32 bytes)
2. **Stockage local** : `flutter_secure_storage` (keychain iOS / keystore Android)
3. **Distribution** : Secret chiffré avec `SecurityService` stocké dans `e2e_keys/{memberId}`
4. **Nouveau membre** : Récupère et déchiffre le secret depuis Firestore

### Fichiers impliqués
- `lib/core/services/message_encryption_service.dart` - Chiffrement/déchiffrement
- `lib/features/tontine/presentation/screens/circle_chat_screen.dart` - Intégration UI
- `lib/core/services/circle_service.dart` - Distribution clés

---

## 11. PLAN D'INTÉGRATION MANGOPAY

### Phase 1 : Setup Mangopay (Semaine 1)
- [ ] Créer compte Mangopay Sandbox : https://hub.mangopay.com
- [ ] Obtenir `ClientId` + `API Key`
- [ ] Configurer webhook URL
- [ ] Ajouter variables `.env`

### Phase 2 : Cloud Functions Mangopay (Semaine 2)
- [ ] `createMangopayUser` - Créer Natural/Legal User
- [ ] `createWallet` - Wallet par utilisateur
- [ ] `createBankAccount` - Lier IBAN (FR/IBAN)
- [ ] `createMandate` - Mandat SEPA Direct Debit
- [ ] `createPayIn` - Prélèvement SEPA DD
- [ ] `createTransfer` - Wallet → Wallet
- [ ] `createPayOut` - Wallet → IBAN bénéficiaire
- [ ] `mangopayWebhook` - Traiter événements

### Phase 3 : Services Flutter (Semaine 3)
- [ ] `mangopay_service.dart` - Client API
- [ ] `mangopay_wallet_service.dart` - Gestion wallets
- [ ] `mangopay_payment_service.dart` - Orchestration paiements
- [ ] `payment_router_service.dart` - Route Mangopay/Stripe

### Phase 4 : UI/UX (Semaine 4)
- [ ] Onboarding Mangopay (KYC + IBAN)
- [ ] Écran wallet utilisateur
- [ ] Historique transactions
- [ ] Absorption frais pour abonnés

### Fichiers à créer
```
lib/core/services/
├── mangopay_service.dart           # Client API Mangopay
├── mangopay_wallet_service.dart    # Gestion wallets
├── mangopay_payment_service.dart   # Paiements tontines
├── stripe_service.dart             # GARDER - Abonnements
└── payment_router_service.dart     # Route vers bon PSP

functions/
├── index.js                        # Point d'entrée
└── mangopay/
    ├── users.js                    # Création users
    ├── wallets.js                  # Gestion wallets
    ├── bankAccounts.js             # IBAN
    ├── mandates.js                 # Mandats SEPA
    ├── payins.js                   # Prélèvements
    ├── transfers.js                # Wallet → Wallet
    ├── payouts.js                  # Vers IBAN
    └── webhook.js                  # Événements
```

### Variables d'environnement
```bash
# .env
MANGOPAY_CLIENT_ID=your_client_id
MANGOPAY_API_KEY=your_api_key
MANGOPAY_ENV=SANDBOX  # ou PRODUCTION
MANGOPAY_WEBHOOK_SECRET=your_webhook_secret

# Firebase Functions config
firebase functions:config:set mangopay.client_id="..." mangopay.api_key="..."
```

### Flux invitation simplifié (3 étapes)
```
Actuel (5 étapes):  Découverte → Contrat → Compte → Attente → PSP
Cible (3 étapes):   Découverte+Contrat → Compte → [Notif Push] → PSP
```

---

> **Note pour Claude** : Toujours commencer par `Read claude_context.md` puis demander "Où en étions-nous ?" si pas de contexte clair.
