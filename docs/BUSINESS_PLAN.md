# 📊 Business Plan - Tontetic

> **Document V18 - Mise à jour : 05 Février 2026**
> Architecture SEPA Pure + Système Marchand + CGU Harmonisées

---

## 1. Executive Summary

### 1.1 Vision
**Tontetic** digitalise les tontines traditionnelles africaines et européennes, en apportant sécurité, transparence et accessibilité via une application mobile moderne.

### 1.2 Proposition de Valeur

| Problème | Solution Tontetic |
|----------|-------------------|
| Tontines informelles = risque de défaut | Garantie conditionnelle SEPA (1 cotisation) |
| Confiance entre membres | Vote démocratique (Borda) + Score d'honneur |
| Gestion papier/Excel | App mobile + Dashboard admin |
| Pas de traçabilité | Logs immuables + Export légal |
| Pas d'assistance | IA Tontii + Support multi-niveaux |
| Pas de marketplace | Espace Marchand intégré |

### 1.3 Chiffres Clés

| Métrique | Valeur |
|----------|--------|
| Plans Particuliers | 4 (Gratuit → Premium) |
| Plans Entreprises | 7 (Starter → Unlimited) |
| Prix max Particulier | 6,99€/mois |
| Prix max Entreprise | Sur devis |
| Marchés cibles | Zone Euro + Zone FCFA |
| Modèle | Freemium + Abonnements + Boost Marchand |

---

## 2. Architecture Technique (V18)

### 2.1 SEPA Pure - Principe Fondamental

> **Tontetic ne touche JAMAIS les fonds des utilisateurs**

| Élément | Architecture V18 |
|---------|-----------------|
| Transit des fonds | Direct membre → bénéficiaire (via PSP) |
| Frais de dossier | ❌ **SUPPRIMÉ** |
| Assurance | ❌ **NON PROPOSÉE** |
| Portefeuille Sécurisé | ❌ **SUPPRIMÉ** |
| Licence ACPR/EME/EMI | ❌ **Non requise** |
| Statut juridique | Prestataire technique (LCEN Art.6) |

### 2.2 Double Mandat SEPA

| Mandat | Type | Déclenchement |
|--------|------|---------------|
| **A - Cotisations** | Prélèvement récurrent | Mensuel automatique |
| **B - Garantie** | Autorisation conditionnelle | Après 3 échecs + 7 jours |

### 2.3 Sécurité Implémentée

| Fonctionnalité | Statut | Fichier |
|----------------|--------|---------|
| Fingerprinting device | ✅ | `device_fingerprint_service.dart` |
| Logs persistants | ✅ | `persistent_audit_service.dart` |
| RGPD (Art. 15, 17, 20) | ✅ | `gdpr_service.dart` |
| IA logging anonyme | ✅ | `ai_conversation_logging_service.dart` |
| KYC | ✅ | `kyc_service.dart` |

---

## 3. Modèle Économique

### 3.1 Sources de Revenus

| Source | Description | % Revenus |
|--------|-------------|-----------|
| **Abonnements Particuliers** | Plans Starter/Standard/Premium | ~60% |
| **Abonnements Entreprises** | Plans B2B | ~25% |
| **Boost Marchand** | Visibilité produits | ~10% |
| **Abonnements Marchands** | Accès Espace Marchand | ~5% |

### 3.2 Plans Particuliers

| Plan | Prix €/mois | Prix FCFA/mois | Tontines | Participants |
|------|-------------|----------------|----------|--------------|
| **Gratuit** | 0 | 0 | 1 | 5 |
| **Starter** | 2,99 | 2 500 | 2 | 10 |
| **Standard** | 4,99 | 4 500 | 3 | 15 |
| **Premium** | 6,99 | 6 500 | 5 | 20 |

**Cotisation max : 500€**

### 3.3 Plans Entreprises (Tontetic Corporate)

| Plan | Salariés | Tontines | Prix €/mois |
|------|----------|----------|-------------|
| **Starter** | 12 | 1 | 19,99 |
| **Starter Pro** | 24 | 2 | 29,99 |
| **Team** | 48 | 4 | 39,99 |
| **Team Pro** | 60 | 4 | 49,99 |
| **Department** | 84 | 7 | 69,99 |
| **Enterprise** | 108 | 10 | 89,99 |
| **Unlimited** | ∞ | ∞ | Sur devis |

**Cotisation max Entreprise : 200€**

### 3.4 Système Marchand (V18)

| Type Marchand | KYC | Limite CA | Offres | Prix/mois |
|---------------|-----|-----------|--------|-----------|
| **Particulier** | Light (email + PSP ID) | 3 000€/an | 5 max | 14,99€ (Unique) |
| **Vérifié** | Complet (SIRET + ID) | Illimité | Illimité | 14,99€ (Unique) |

**Revenus Boost :**
| Option | Prix | Durée |
|--------|------|-------|
| Boost Simple | 500 FCFA | 1 jour |
| Boost Premium | 2 000 FCFA | 7 jours |
| Page d'Accueil | 5 000 FCFA | 24h |

> ⚠️ **Crucial** : Aucune commission sur les ventes. Pas de paiement in-app.

### 3.5 Offre de Lancement "Pionniers"

| Paramètre | Valeur |
|-----------|--------|
| Créateurs éligibles | 20 premiers |
| Durée offerte | 3 mois Starter GRATUIT |
| Invitations par créateur | 9 personnes max |
| Portée maximale | **200 utilisateurs** |
| Après 3 mois | Bascule auto forfait choisi |

---

## 4. Cadre Juridique (CGU Harmonisées V18)

### 4.1 Structure CGU

| Section | Articles | Contenu Principal |
|---------|----------|-------------------|
| **Générale** | 1-10 | Tontines, Cotisations, Garanties, Blocage Volontaire |
| **Utilisateurs** | 1-20 | Création compte, Vote/Aléatoire, Responsabilités |
| **Entreprises** | 1-17 | Plans B2B, Limites 200€, Dashboard |
| **Marchands** | 1-20 | LCEN Art.6, Pas vente, Boost |

### 4.2 Points Clés Juridiques

| Principe | Implémentation |
|----------|----------------|
| Prestataire technique LCEN | ✅ CGU + UI disclaimers |
| Pas établissement de paiement | ✅ Architecture SEPA Pure |
| Pas détention de fonds | ✅ Transit direct PSP |
| Interdiction wallet interne | ✅ UI "Portefeuille Sécurisé" |
| Garantie = autorisation | ✅ `sepa_guarantee_service.dart` |
| IA = pas conseil financier | ✅ `gemini_service.dart` |

### 4.3 Conformité Réglementaire

| Réglementation | Conformité | Justification |
|----------------|------------|---------------|
| **Agrément EME** | Non requis | Pas de détention de fonds |
| **RGPD** | ✅ Conforme | Export/suppression/anonymisation |
| **LCEN Art.6** | ✅ Hébergeur | Modération contenu |
| **DSP2** | ✅ Via PSP | Stripe/Wave agréés |
| **LCB-FT** | ✅ Partiellement | Plafonds + KYC |

---

## 5. Fonctionnalités Produit (23 Modules)

```
lib/features/
├── admin/          # Back-office admin
├── advertising/    # Publicité/boosts + Espace Marchand
├── ai/             # IA Tontii (Gemini)
├── auth/           # Authentification
├── chat/           # Messagerie cercles
├── corporate/      # B2B entreprises (7 plans)
├── dashboard/      # Tableau de bord
├── kyc/            # Vérification identité
├── legal/          # CGU harmonisées
├── merchant/       # Espace marchand (Particulier/Vérifié)
├── onboarding/     # Tutoriel démarrage
├── payments/       # SEPA Pure + Garanties
├── referral/       # Parrainage
├── savings/        # Blocage Volontaire de Fonds
├── security/       # Fingerprinting + Logs
├── settings/       # Préférences + RGPD
├── shop/           # Marketplace
├── social/         # Partage social
├── subscription/   # Abonnements (Particuliers + Entreprises)
├── tontine/        # Cœur métier
└── wallet/         # Portefeuille Sécurisé (Agent PSP)
```

---

## 6. Projections Financières

### 6.1 Hypothèses

| Variable | Y1 | Y2 | Y3 |
|----------|----|----|----| 
| Utilisateurs actifs | 5 000 | 25 000 | 100 000 |
| % Payants | 30% | 40% | 50% |
| ARPU moyen | 2,50€ | 3,50€ | 4,50€ |
| Entreprises B2B | 10 | 50 | 200 |

### 6.2 Revenus Projetés

| Source | Y1 | Y2 | Y3 |
|--------|----|----|----| 
| **Abonnements Particuliers** | 15 000€ | 105 000€ | 540 000€ |
| **Abonnements Entreprises** | 3 600€ | 36 000€ | 180 000€ |
| **Boost Marchand** | 1 000€ | 15 000€ | 75 000€ |
| **Total** | **19 600€** | **156 000€** | **795 000€** |

---

## 7. Go-to-Market

| Phase | Durée | Objectif |
|-------|-------|----------|
| **MVP** | Mois 1-3 | 500 beta-testeurs diaspora |
| **Soft Launch** | Mois 4-6 | 5 000 utilisateurs FR |
| **Expansion FCFA** | Mois 7-12 | Sénégal, Côte d'Ivoire |
| **Scale** | Y2+ | 100K utilisateurs |

---

## 8. Risques & Mitigation

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Fraude/défauts massifs | Moyen | Élevé | Garantie 1 cotisation + KYC |
| Blocage PSP | Faible | Très élevé | Multi-PSP (Stripe+Wave+Orange) |
| Concurrence | Moyen | Moyen | Différenciation AI+UX+Marchand |
| Réglementation FCFA | Faible | Élevé | Partenariat EME local |
| Requalification PSP | Faible | Très élevé | Architecture SEPA Pure stricte |

---

## 9. KPIs à Suivre

| KPI | Définition | Cible Y1 |
|-----|------------|----------|
| **MAU** | Utilisateurs actifs mensuels | 5 000 |
| **Conversion** | Gratuit → Payant | 30% |
| **Churn** | Perte abonnés mensuelle | <5% |
| **ARPU** | Revenu moyen par utilisateur | 2,50€ |
| **NPS** | Score recommandation | >50 |
| **Entreprises B2B** | Comptes actifs | 10 |
| **Marchands actifs** | Particulier + Vérifié | 50 |

---

## 10. Équipe & Structure

| Rôle | Responsabilités |
|------|-----------------|
| **CEO** | Stratégie, Levée de fonds, Partenariats |
| **CTO** | Architecture SEPA Pure, Sécurité, DevOps |
| **CPO** | UX/UI, Roadmap produit, Beta testing |
| **Legal** | CGU, Conformité, RGPD |
| **Growth** | Marketing, Community, Parrainage |

---

## Annexes

- [BUSINESS_PLAN_ANNEXES.md](./BUSINESS_PLAN_ANNEXES.md) - Matrices détaillées
- [CGU Complètes](../lib/core/constants/legal_texts.dart) - Articles 1-10 + Marchands 1-20

---

*Document V18 - Généré le : 05 Février 2026*
*Basé sur : Analyse du code source Tontetic + Audit CGU*
