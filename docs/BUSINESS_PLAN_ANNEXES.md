# 📊 Business Plan Annexes - Document Complet

> **Document V18 - Mise à jour : 05 Février 2026**
> Annexes détaillées avec analyses stratégiques et financières
> **Statut juridique : Auto-Entrepreneur**

---

## TABLE DES MATIÈRES

1. [Plans Tarifaires](#a-plans-tarifaires-complets)
2. [Architecture Technique](#b-architecture-sepa-pure)
3. [CGU Harmonisées](#c-cgu-harmonisées)
4. [Étude de Marché](#d-étude-de-marché)
5. [Analyse PESTEL](#e-analyse-pestel)
6. [Analyse SWOT](#f-analyse-swot)
7. [Analyse Concurrentielle](#g-analyse-concurrentielle)
8. [Coûts & Charges](#h-coûts-et-charges)
9. [Plan Marketing](#i-plan-marketing)
10. [Projections Financières](#j-projections-financières)
11. [Personas](#k-personas)
12. [Équipe & Structure](#l-équipe-et-structure)
13. [Roadmap](#m-roadmap-produit)
14. [Levée de Fonds](#n-levée-de-fonds)

---

## A. Plans Tarifaires Complets

### A.1 Plans Particuliers

| Plan | Prix €/mois | Prix FCFA/mois | Tontines | Participants | Cotisation Max |
|------|-------------|----------------|----------|--------------|----------------|
| **Gratuit** | 0 | 0 | 1 | 5 | 500€ |
| **Starter** | 2,99 | 2 000 | 2 | 10 | 500€ |
| **Standard** | 4,99 | 3 500 | 3 | 15 | 500€ |
| **Premium** | 6,99 | 4 500 | 5 | 20 | 500€ |

> 💬 *Commentaire : Les prix sont alignés sur les standards SaaS freemium. Le plan Gratuit sert d'acquisition, Starter est le point d'entrée payant psychologiquement accessible (<3€).*

### A.2 Plans Entreprises (Tontetic Corporate)

| Plan | Salariés | Tontines | Prix €/mois | Support | Cotisation Max |
|------|----------|----------|-------------|---------|----------------|
| **Starter** | 12 | 1 | 19,99 | Flexible | 200€ |
| **Starter Pro** | 24 | 2 | 29,99 | Flexible | 200€ |
| **Team** | 48 | 4 | 39,99 | Flexible | 200€ |
| **Team Pro** | 60 | 4 | 49,99 | Prioritaire | 200€ |
| **Department** | 84 | 7 | 69,99 | Prioritaire | 200€ |
| **Enterprise** | 108 | 10 | 89,99 | Dédié | 200€ |
| **Unlimited** | ∞ | ∞ | Sur devis | Premium 24/7 | Sur devis |

> 💬 *Commentaire : Multiples de 12 (équipes types). Prix calés sur le marché B2B SaaS (20-100€/mois pour outils RH/bien-être).*

### A.3 Système Marchand

| Type | KYC Requis | Limite CA | Offres Max | Prix/mois |
|------|------------|-----------|------------|-----------|
| **Particulier** | Email + PSP ID | 3 000€/an | 5 | 14,99€ (Unique) |
| **Vérifié** | SIRET/NINEA + ID + Selfie | Illimité | Illimité | 14,99€ (Unique) |

> 💬 *Commentaire : Le plafond 3 000€/an pour Particulier correspond au seuil micro-BNC simplifié. Au-delà = obligation de SIRET.*

### A.4 Options Boost Marchand (Source code)

| Option | Prix € | Durée | Disponibilité |
|--------|--------|-------|---------------|
| Boost 1 jour | 1,99€ | 1 jour | Tous |
| Boost 7 jours | 9,99€ | 7 jours | Tous |
| Mise en avant Homepage | 29,99€ | 30 jours | Vérifié uniquement |

> 💬 *Commentaire : Prix basés sur les standards pub social (1-10€/jour). Le boost Homepage est premium car très visible.*

### A.5 Offre de Lancement "Pionniers"

| Paramètre | Valeur |
|-----------|--------|
| Créateurs éligibles | 20 premiers |
| Durée offerte | 3 mois Starter GRATUIT |
| Invitations par créateur | 9 personnes max |
| Portée maximale | **200 utilisateurs** |
| Après 3 mois | Bascule auto forfait choisi |

> 💬 *Commentaire : 20×10 = 200 utilisateurs qualifiés via bouche-à-oreille. Coût d'opportunité : 200×3×2,99€ = ~1 800€ de revenus différés.*

---

## B. Architecture SEPA Pure

### B.1 Principe Fondamental

> **Tontetic ne touche JAMAIS l'argent des utilisateurs**

| Élément | Architecture V18 |
|---------|-----------------|
| Transit des fonds | Direct membre → bénéficiaire (via PSP) |
| Frais de dossier | ❌ SUPPRIMÉ |
| Assurance | ❌ NON PROPOSÉE |
| Portefeuille Sécurisé | ❌ SUPPRIMÉ |
| Licence ACPR/EME/EMI | ❌ Non requise |

### B.2 Double Mandat SEPA

| Mandat | Type | Déclenchement |
|--------|------|---------------|
| A - Cotisations | Prélèvement récurrent | Mensuel automatique |
| B - Garantie | Autorisation conditionnelle | Après 3 échecs + 7 jours |

> 💬 *Commentaire : Cette architecture évite toute requalification en établissement de paiement. Conformité DSP2 via PSP agréés.*

---

## C. CGU Harmonisées

### C.1 Structure

| Section | Articles | Contenu |
|---------|----------|---------|
| Générale | 1-10 | Tontines, Cotisations, Garanties, Blocage |
| Utilisateurs | 1-20 | Création compte, Vote, Responsabilités |
| Entreprises | 1-17 | Plans B2B, Limites, Dashboard |
| Marchands | 1-20 | LCEN Art.6, Boost, Pas vente |

### C.2 Conformité Réglementaire

| Réglementation | Statut | Justification |
|----------------|--------|---------------|
| Agrément EME | Non requis | Pas de détention de fonds |
| RGPD | ✅ Conforme | `gdpr_service.dart` |
| LCEN Art.6 | ✅ Hébergeur | Modération contenu |
| DSP2 | ✅ Via PSP | Stripe/Wave agréés |

---

## D. Étude de Marché

### D.1 TAM / SAM / SOM

| Niveau | Population | Estimation | Source |
|--------|------------|------------|--------|
| **TAM** (Total Addressable Market) | Population bancarisée Afrique + Diaspora | ~150M personnes | Banque Mondiale 2023 [À VÉRIFIER] |
| **SAM** (Serviceable Available Market) | Smartphone + data + pratique tontines | ~30M personnes | Estimation GSMA [À VÉRIFIER] |
| **SOM** (Serviceable Obtainable Market) | Adoption 1ère année réaliste | ~50K utilisateurs | Estimation interne |

> 💬 *Commentaire : TAM basé sur pop. bancarisée UEMOA (~40%) + diaspora Europe (~3M). SAM = 20% pratiquent activement des tontines.*

### D.2 Marché des Tontines

| Région | Population | % Pratiquants Tontines | Marché Potentiel |
|--------|------------|------------------------|------------------|
| **Sénégal** | 17M | ~40% [À VÉRIFIER] | ~7M personnes |
| **Côte d'Ivoire** | 27M | ~35% [À VÉRIFIER] | ~9M personnes |
| **Mali** | 21M | ~30% [À VÉRIFIER] | ~6M personnes |
| **Cameroun** | 27M | ~45% [À VÉRIFIER] | ~12M personnes |
| **Diaspora France** | ~1,5M | ~60% [À VÉRIFIER] | ~900K personnes |

> 💬 *Commentaire : Les % sont estimés sur base d'études BIT et enquêtes terrain. Diaspora = taux élevé car maintien traditions.*

### D.3 Tendances Marché

| Tendance | Impact | Opportunité |
|----------|--------|-------------|
| Digitalisation Afrique | ↗️ Fort | Adoption mobile money +30%/an |
| Réglementation fintech | ↔️ Moyen | SEPA Pure = pas de licence |
| Diaspora connectée | ↗️ Fort | Transferts d'argent : 45Md$/an vers Afrique |
| Concurrence faible | ↗️ Fort | Aucune app tontine majeure identifiée |

---

## E. Analyse PESTEL

### E.1 Facteurs Politiques

| Facteur | Impact | Analyse |
|---------|--------|---------|
| Stabilité politique Afrique Ouest | ↔️ Moyen | Risques Mali/Burkina, stable Sénégal/CI |
| Relations France-Afrique | ↔️ Moyen | Tensions mais diaspora reste connectée |
| Politiques fintech UEMOA | ↗️ Positif | Encouragement innovation (BCEAO) |
| Réglementation ACPR France | ↔️ Neutre | SEPA Pure = exempt |

### E.2 Facteurs Économiques

| Facteur | Impact | Analyse |
|---------|--------|---------|
| Inflation zone Euro | ↘️ Négatif | ~2-3% en 2025, pouvoir d'achat stable |
| Croissance PIB Afrique | ↗️ Positif | +4-6%/an en moyenne (FMI) |
| Taux de change EUR/FCFA | ↔️ Stable | Parité fixe : 1€ = 655,957 FCFA |
| Bancarisation Afrique | ↗️ Positif | ~45% UEMOA, en hausse [À VÉRIFIER] |

### E.3 Facteurs Socioculturels

| Facteur | Impact | Analyse |
|---------|--------|---------|
| Tradition tontines | ↗️ Très positif | Pratique ancestrale = confiance établie |
| Digitalisation génération Z | ↗️ Positif | 70% des 18-35 ans sur smartphone |
| Solidarité communautaire | ↗️ Positif | Valeur centrale en Afrique de l'Ouest |
| Méfiance bancaire | ↗️ Positif | Tontines = alternative historique |

### E.4 Facteurs Technologiques

| Facteur | Impact | Analyse |
|---------|--------|---------|
| Pénétration smartphone | ↗️ Positif | ~55% Afrique sub-saharienne (GSMA 2024) |
| Couverture 4G/5G | ↔️ Moyen | 4G : 70% zones urbaines, rural limité |
| Mobile Money (Wave, Orange) | ↗️ Très positif | +40%/an, infrastructure PSP existante |
| IA générative | ↗️ Positif | Tontii = différenciateur UX unique |

### E.5 Facteurs Environnementaux

| Facteur | Impact | Analyse |
|---------|--------|---------|
| Économie circulaire | ↗️ Positif | Tontines = épargne locale solidaire |
| Impact carbone digital | ↔️ Neutre | Serveurs cloud (AWS/GCP = neutralité carbone) |

### E.6 Facteurs Légaux

| Facteur | Impact | Analyse |
|---------|--------|---------|
| RGPD Europe | ↔️ Neutre | Conformité implémentée (export/suppression) |
| Réglementation PSP | ↗️ Positif | Via Stripe/Wave = agréés |
| DSP2 | ↗️ Positif | Open Banking = opportunité |
| LCB-FT (Anti-blanchiment) | ↔️ Moyen | Plafonds 500€/200€ + KYC = conformité |

---

## F. Analyse SWOT

### F.1 Forces (Strengths)

| Force | Détail |
|-------|--------|
| **Architecture SEPA Pure** | Pas de licence requise, conformité simplifiée |
| **Double devise EUR/FCFA** | Marché diaspora + Afrique natif |
| **Garantie automatique** | 1 cotisation, déclenchement objectif et transparent |
| **Vote démocratique (Borda)** | Équité dans l'ordre des pots, innovation UX |
| **IA Tontii** | Différenciateur UX unique sur le marché |
| **Score d'Honneur** | Confiance communautaire quantifiée |
| **7 plans entreprise** | Flexibilité B2B complète |
| **Espace Marchand** | Revenus complémentaires diversifiés |

### F.2 Faiblesses (Weaknesses)

| Faiblesse | Détail |
|-----------|--------|
| **Pas de traction** | MVP en développement, 0 utilisateurs réels |
| **Équipe réduite** | Solo founder en Y1 |
| **Budget marketing limité** | ~500€ max en Y1 (auto-entrepreneur) |
| **Dépendance PSP** | Stripe/Wave peuvent changer conditions |
| **Pas de présence physique Afrique** | Opérations 100% remote |

### F.3 Opportunités (Opportunities)

| Opportunité | Détail |
|-------------|--------|
| **Marché non digitalisé** | 95%+ tontines encore informelles (WhatsApp/papier) |
| **Diaspora importante** | ~1,5M Sénégalais en France, forte pratique |
| **Mobile Money en croissance** | Wave, Orange Money = PSP locaux prêts |
| **Pas de concurrent direct** | Aucune app tontine majeure identifiée |
| **B2B sous-exploité** | Tontines d'entreprise = niche vierge |

### F.4 Menaces (Threats)

| Menace | Détail |
|--------|--------|
| **Réglementation future** | Risque de reclassification PSP par ACPR |
| **Entrée banques/fintechs** | Orange, Wave, Revolut pourraient copier |
| **Fraude massive** | Risque réputation si défauts en cascade |
| **Instabilité politique** | Risque pays Sahel (Mali, Burkina) |

---

## G. Analyse Concurrentielle

### G.1 Concurrents Directs

| Critère | Tontetic | Concurrent Direct |
|---------|----------|------------------|
| **Nom** | Tontetic | Aucun identifié à ce jour |
| **Zone** | FR + FCFA | - |
| **Double devise** | ✅ | - |
| **Garantie auto** | ✅ | - |
| **IA intégrée** | ✅ | - |
| **B2B** | ✅ | - |

> 💬 *Commentaire : Recherche concurrentielle à approfondir. Pas de concurrent direct majeur identifié sur le créneau "tontine digitale + garantie + B2B".*

### G.2 Concurrents Indirects

| Type | Exemples | Faiblesse vs Tontetic |
|------|----------|----------------------|
| **Groupes WhatsApp** | Tontines informelles | Pas de sécurité, pas de traçabilité |
| **Excel/Cahiers** | Gestion manuelle | Erreurs, pas de garantie |
| **Banques trad.** | Produits épargne | Pas culturellement adapté |
| **Mobile Money** | Wave, Orange | Pas de gestion tontine intégrée |

---

## H. Coûts et Charges

### H.1 Coûts Fixes Mensuels (Auto-Entrepreneur Y1)

| Poste | Description | Coût/mois | Coût/an | Statut |
|-------|-------------|-----------|---------|--------|
| **Supabase** | BDD PostgreSQL (Free→Pro) | 0€→25€ | **~150€** | Estimé |
| **Firebase** | Auth + Notifications (Spark) | 0€ | **0€** | Gratuit |
| **Gemini API** | IA Tontii (pay-per-use) | ~15€ | **~180€** | [À VÉRIFIER] |
| **Domaine** | tontetic.io (.io = premium) | ~2€ | **~25€** | Estimé |
| **Google Workspace** | Email pro (Starter) | 6€ | **72€** | Fixe |
| **Cloudflare** | CDN + SSL (Free) | 0€ | **0€** | Gratuit |
| **App Store iOS** | Licence développeur Apple | - | **99€** | Fixe |
| **Play Store** | Licence unique Google | - | **25€** | Fixe unique |
| **SOUS-TOTAL TECH** | | | **~550€** | |

> 💬 *Commentaire : Stack optimisée pour coûts minimaux. Supabase free tier suffit jusqu'à ~10K users. Firebase Spark gratuit jusqu'à 10K auth/mois.*

### H.2 Coûts Fixes Admin (Auto-Entrepreneur Y1)

| Poste | Description | Coût/an | Statut |
|-------|-------------|---------|--------|
| **Création Auto-Entrepreneur** | Gratuit (URSSAF en ligne) | **0€** | Fixe |
| **CFE** | Cotisation Foncière Entreprises | **0€** (exonéré Y1) | Fixe |
| **Comptabilité** | DIY (livre recettes) | **0€** | - |
| **Compte bancaire** | Compte dédié (Qonto/Shine free) | **0€** | Optionnel |
| **Assurance RC Pro** | Optionnel Y1 | **0€** | Optionnel |
| **SOUS-TOTAL ADMIN** | | **~0€** | |

> 💬 *Commentaire : L'auto-entrepreneur bénéficie d'exonérations Y1. Pas d'obligation comptable complexe. RC Pro recommandée mais non obligatoire pour activité numérique.*

### H.3 Coûts Variables Y1

| Poste | Base de Calcul | Estimation Y1 | Statut |
|-------|----------------|---------------|--------|
| **Stripe fees** | 1,4% + 0,25€/tx | **~280€** | Estimé |
| | Sur ~15 000€ revenus, ~300 tx | | |
| **Wave fees** | ~1,5%/tx [À VÉRIFIER] | **~75€** | [À VÉRIFIER] |
| | Sur ~5 000€ revenus FCFA | | |
| **SMS OTP** | 0,04€/SMS × 5 000 users | **~200€** | Estimé |
| **Emails transactionnels** | SendGrid Free (100/jour) | **0€** | Gratuit |
| **SOUS-TOTAL VARIABLE** | | **~555€** | |

> 💬 *Commentaire : Stripe = 1,4% + 0,25€/tx Europe. Wave = variable selon pays (1-2%). SMS via Twilio/Vonage à ~0,04€/SMS France.*

### H.4 Charges Sociales Auto-Entrepreneur

| Poste | Taux | Base CA estimée | Montant Y1 |
|-------|------|-----------------|------------|
| **Cotisations URSSAF** | 21,2% (BNC) | ~20 000€ | **~4 240€** |
| **CFP (Formation Pro)** | 0,2% | ~20 000€ | **~40€** |
| **TOTAL CHARGES SOCIALES** | | | **~4 280€** |

> 💬 *Commentaire : Taux BNC 2025 = 21,2% pour prestations de services. Versement trimestriel ou mensuel au choix. CFP = contribution formation professionnelle.*

### H.5 Récapitulatif Coûts Y1 (Auto-Entrepreneur Solo)

| Catégorie | Montant | Notes |
|-----------|---------|-------|
| **Infrastructure Tech** | ~550€ | Optimisé free tiers |
| **Admin/Juridique** | ~0€ | Exonérations AE |
| **Coûts Variables** | ~555€ | PSP + SMS |
| **Charges Sociales** | ~4 280€ | 21,2% du CA |
| **Marketing** | ~500€ | Budget minimal |
| **TOTAL COÛTS Y1** | **~5 885€** | |

### H.6 Impôts Y1 (Auto-Entrepreneur)

| Option | Calcul | Montant |
|--------|--------|---------|
| **Prélèvement libératoire** | 2,2% × CA | ~440€ |
| **OU Barème IR** | Abattement 34% + tranche | Variable selon situation |

> 💬 *Commentaire : Prélèvement libératoire = option simple si éligible (revenu fiscal N-2 < seuil). Sinon IR classique avec abattement 34% sur CA.*

---

## I. Plan Marketing

### I.1 Budget Marketing Y1 (Minimal)

| Poste | Budget Y1 | Stratégie |
|-------|-----------|-----------|
| **Ads Facebook/Instagram** | ~300€ | Tests ciblés diaspora |
| **TikTok organique** | 0€ | Contenus viraux DIY |
| **Canva Pro** | ~120€ | Création visuels |
| **Partenariats** | 0€ | Échange visibilité associations |
| **TOTAL MARKETING Y1** | **~420€** | Budget bootstrap |

> 💬 *Commentaire : Budget minimal assumé pour Y1. Focus sur acquisition organique (parrainage, WhatsApp viral, TikTok). Ads = tests seulement.*

### I.2 Stratégie d'Acquisition

| Canal | Cible | CAC Estimé | LTV Attendu | Ratio |
|-------|-------|------------|-------------|-------|
| **Parrainage organique** | Diaspora FR | ~0€ | ~50€ | ∞ |
| **WhatsApp viral** | Groupes existants | ~0€ | ~60€ | ∞ |
| **Facebook Ads** | 25-45 ans diaspora | ~8€ [À VÉRIFIER] | ~50€ | 6:1 |
| **TikTok organique** | 18-35 ans | ~0€ | ~40€ | ∞ |
| **Partenariats associations** | Communautés diaspora | ~0€ | ~70€ | ∞ |

> 💬 *Commentaire : CAC Facebook basé sur benchmarks fintech Afrique (5-15€). LTV = ARPU × durée moyenne abonnement (~12-18 mois).*

### I.3 Funnel Marketing

```
AWARENESS (Notoriété)
   │ Ads, TikTok, Bouche-à-oreille
   ▼
INTEREST (Intérêt)
   │ Téléchargement App, Inscription
   │ Objectif: 10 000 downloads Y1
   ▼
CONSIDERATION (Évaluation)
   │ Plan Gratuit, 1ère tontine
   │ Objectif: 5 000 inscrits actifs
   ▼
CONVERSION (Achat)
   │ Upgrade Starter/Standard/Premium
   │ Objectif: 30% conversion = 1 500 payants
   ▼
LOYALTY (Fidélité)
   │ Renouvellement, 2ème cercle
   │ Objectif: Churn <5%/mois
   ▼
ADVOCACY (Ambassadeur)
   │ Parrainage jusqu'à 9 personnes
   │ Objectif: 3 parrainages/user actif
```

### I.4 Calendrier Marketing Y1

| Mois | Action | Budget | Objectif |
|------|--------|--------|----------|
| M1-M3 | **Beta privée** | 0€ | 500 testeurs |
| M4 | **Lancement officiel** | ~100€ | 2 000 inscriptions |
| M5-M6 | **Campagne diaspora FR** | ~200€ | 5 000 utilisateurs |
| M7-M9 | **Expansion Sénégal** | ~100€ | 15 000 utilisateurs |
| M10-M12 | **Côte d'Ivoire** | ~100€ | 30 000 utilisateurs |

---

## J. Projections Financières

### J.1 Hypothèses de Base

| Variable | Y1 | Y2 | Y3 |
|----------|----|----|-----|
| Utilisateurs totaux | 5 000 | 25 000 | 100 000 |
| % Gratuit | 70% | 60% | 50% |
| % Starter (2,99€) | 15% | 20% | 25% |
| % Standard (4,99€) | 10% | 12% | 15% |
| % Premium (6,99€) | 5% | 8% | 10% |
| **ARPU moyen** | ~2,50€ | ~3,50€ | ~4,50€ |

> 💬 *Commentaire : Distribution basée sur benchmarks SaaS freemium (60-70% gratuit Y1). ARPU augmente avec conversion progressive.*

### J.2 Revenus Projetés

| Source | Y1 | Y2 | Y3 | Calcul |
|--------|----|----|-----|--------|
| **Abonnements Particuliers** | **15 000€** | 105 000€ | 540 000€ | Users × %payants × ARPU × 12 |
| **Abonnements Entreprises** | **3 600€** | 36 000€ | 180 000€ | 10→50→200 × ~30-75€ × 12 |
| **Abonnements Marchands** | **600€** | 6 000€ | 30 000€ | 10→50→250 × ~5-10€ × 12 |
| **Boost Marchand** | **500€** | 5 000€ | 25 000€ | ~20→200→1000 boosts × 25€ |
| **TOTAL REVENUS** | **~19 700€** | **~152 000€** | **~775 000€** | |

> 💬 *Commentaire : Y1 conservateur. Y2-Y3 supposent traction confirmée et levée de fonds pour accélérer.*

### J.3 Compte de Résultat Y1 (Auto-Entrepreneur)

| Ligne | Montant | Notes |
|-------|---------|-------|
| **Chiffre d'affaires** | ~20 000€ | Plafond AE = 77 700€ |
| (-) Coûts variables | -555€ | PSP + SMS |
| **Marge brute** | **~19 445€** | 97% |
| (-) Coûts fixes tech | -550€ | Infra cloud |
| (-) Marketing | -420€ | Budget minimal |
| (-) Charges sociales | -4 280€ | 21,2% URSSAF |
| (-) Impôt (PL 2,2%) | -440€ | Optionnel |
| **Résultat net** | **~13 755€** | Profit Y1 |

> 💬 *Commentaire : Rentabilité dès Y1 grâce au statut AE et coûts maîtrisés. Marge très saine car modèle SaaS pur (pas de COGS physique).*

### J.4 Break-Even Analysis

| Métrique | Valeur |
|----------|--------|
| **Coûts fixes mensuels** | ~130€ (tech + marketing/12) |
| **ARPU moyen** | ~2,50€ |
| **Users payants pour BE** | ~52/mois |
| **Mois estimé BE** | **M4-M5** (après lancement) |

> 💬 *Commentaire : Break-even très rapide car coûts fixes minimaux. Dès ~150 users payants, rentabilité mensuelle atteinte.*

---

## K. Personas

### K.1 Aminata - Diaspora France

| Attribut | Valeur |
|----------|--------|
| Âge | 32 ans |
| Localisation | Paris 18ème (Goutte d'Or) |
| Profession | Infirmière |
| Revenus | 2 200€ net/mois |
| Origine | Sénégal (Thiès) |
| Usage actuel | 1 tontine WhatsApp famille (80€/mois) |
| Frustrations | Pas de garantie, pas de trace écrite |
| Objectifs | Sécuriser sa tontine, avoir des preuves |
| **Plan probable** | Starter (2,99€) |
| **LTV estimée** | ~60€ (15 mois) |

### K.2 Moussa - Urbain Afrique

| Attribut | Valeur |
|----------|--------|
| Âge | 28 ans |
| Localisation | Dakar (Plateau) |
| Profession | Commercial automobile |
| Revenus | 350 000 FCFA/mois (~535€) |
| Usage actuel | 2 tontines collègues (25 000 FCFA/mois) |
| Frustrations | Organisateur peu fiable |
| Objectifs | Créer ses propres cercles |
| **Plan probable** | Standard (4 500 FCFA) |
| **LTV estimée** | ~45€ (12 mois) |

### K.3 Entreprise - RH PME

| Attribut | Valeur |
|----------|--------|
| Taille entreprise | 50-100 salariés |
| Secteur | Services / BTP / Commerce |
| Budget bien-être | ~500-2 000€/an |
| Besoins | Cohésion équipe, avantage salarié |
| **Plan probable** | Team (39,99€) ou Department (69,99€) |
| **LTV estimée** | ~700€ (12 mois moyenne) |

---

## L. Équipe et Structure

### L.1 Équipe Y1 (Solo Founder)

| Poste | Nom | Statut | Rémunération Y1 |
|-------|-----|--------|-----------------|
| **Fondateur / CEO / CTO** | [À COMPLÉTER] | Auto-Entrepreneur | ~13 755€ (résultat net) |

> 💬 *Commentaire : Mode bootstrap. Pas de salaire fixe, rémunération = bénéfice net après charges.*

### L.2 Structure Juridique

| Élément | Valeur |
|---------|--------|
| **Statut** | Auto-Entrepreneur (Micro-BNC) |
| **Activité** | Édition de logiciels applicatifs |
| **Code APE** | 5829C [À VÉRIFIER] |
| **Plafond CA** | 77 700€/an |
| **TVA** | Franchise en base (pas de TVA) |
| **Siège social** | [À COMPLÉTER] |
| **SIRET** | [À COMPLÉTER après création] |

### L.3 Évolution Y2+ (Si traction)

| Étape | Action | Timing |
|-------|--------|--------|
| CA > 50K€ | Passage en EURL/SASU | Fin Y1 ou Y2 |
| Levée de fonds | Création SAS | Avant levée |
| 1er recrutement | Alternant dev/marketing | Y2 |

---

## M. Roadmap Produit

### M.1 Q1 2026 (Fait)

| Feature | Priorité | Statut |
|---------|----------|--------|
| MVP Core (Tontines) | ⭐⭐⭐ | ✅ Fait |
| Double devise EUR/FCFA | ⭐⭐⭐ | ✅ Fait |
| Garantie SEPA | ⭐⭐⭐ | ✅ Fait |
| IA Tontii | ⭐⭐ | ✅ Fait |
| Espace Marchand | ⭐⭐ | ✅ Fait |
| Plans Entreprise | ⭐⭐ | ✅ Fait |

### M.2 Q2 2026

| Feature | Priorité | Statut |
|---------|----------|--------|
| App Store iOS | ⭐⭐⭐ | ⬜ À faire |
| Play Store Android | ⭐⭐⭐ | ⬜ À faire |
| Stripe Production | ⭐⭐⭐ | ⬜ À faire |
| Wave Production | ⭐⭐⭐ | ⬜ À faire |

### M.3 Q3-Q4 2026

| Feature | Priorité | Statut |
|---------|----------|--------|
| Multi-langue (Français/Wolof) | ⭐⭐ | ✅ Fait |
| Notifications avancées | ⭐⭐ | ⬜ |
| API partenaires | ⭐ | ⬜ |

---

## N. Levée de Fonds

### N.1 Stratégie Y1 (Bootstrap)

| Approche | Détail |
|----------|--------|
| **Mode** | Bootstrap / Auto-financement |
| **Montant investi** | ~1 000-2 000€ perso |
| **Objectif** | Prouver traction avant levée |
| **Milestone levée** | 5 000 users actifs + 500 payants |

### N.2 Levée Future (Si traction Y1)

| Round | Montant Cible | Valorisation Pre | Dilution | Timing |
|-------|---------------|------------------|----------|--------|
| **Pré-seed** | 50-100K€ | 300-500K€ | 15-25% | Y2 |
| **Seed** | 300-500K€ | 1-2M€ | 15-25% | Y2-Y3 |

### N.3 Utilisation des Fonds (Pré-seed 100K€)

| Poste | % | Montant | Détail |
|-------|---|---------|--------|
| **Développement** | 30% | 30 000€ | iOS/Android natif, API |
| **Marketing** | 40% | 40 000€ | Acquisition diaspora + Afrique |
| **RH** | 20% | 20 000€ | 1 dev alternant |
| **Trésorerie** | 10% | 10 000€ | Runway 12 mois |

### N.4 Investisseurs Cibles

| Type | Exemples | Fit |
|------|----------|-----|
| **Business Angels diaspora** | Communauté Sénégal/CI en FR | ⭐⭐⭐ |
| **VC Afrique early-stage** | Partech Africa, Orange Ventures | ⭐⭐ |
| **Programmes publics** | BPI France, French Tech | ⭐⭐ |

---

## O. KPIs à Suivre

| KPI | Définition | Cible Y1 | Cible Y2 | Cible Y3 |
|-----|------------|----------|----------|----------|
| **MAU** | Utilisateurs actifs mensuels | 3 000 | 20 000 | 80 000 |
| **Conversion** | Gratuit → Payant | 30% | 40% | 50% |
| **Churn** | Perte abonnés mensuelle | <5% | <4% | <3% |
| **ARPU** | Revenu moyen par utilisateur | 2,50€ | 3,50€ | 4,50€ |
| **NPS** | Score recommandation | >40 | >50 | >60 |
| **CAC** | Coût acquisition client | <5€ | <10€ | <8€ |
| **LTV** | Valeur vie client | >40€ | >50€ | >60€ |
| **LTV/CAC** | Ratio valeur/coût | >8 | >5 | >7 |

> 💬 *Commentaire : LTV/CAC > 3 = sain. Objectif Y1 = acquisition organique donc CAC très bas. Y2 avec budget = CAC augmente mais reste rentable.*

---

## P. Annexe - Glossaire

| Terme | Définition |
|-------|------------|
| **ARPU** | Average Revenue Per User - Revenu moyen par utilisateur |
| **CAC** | Customer Acquisition Cost - Coût d'acquisition client |
| **LTV** | Lifetime Value - Valeur vie client |
| **Churn** | Taux d'attrition mensuel des abonnés |
| **NPS** | Net Promoter Score - Score de recommandation |
| **TAM/SAM/SOM** | Total/Serviceable/Obtainable Market - Niveaux de marché |
| **PSP** | Payment Service Provider - Prestataire de paiement (Stripe, Wave) |
| **SEPA** | Single Euro Payments Area - Zone de paiement européenne |
| **AE** | Auto-Entrepreneur (statut juridique français) |
| **BNC** | Bénéfices Non Commerciaux (catégorie fiscale) |

---

*Document V18 - Généré le : 05 Février 2026*
*Statut : Auto-Entrepreneur Y1*
*Les mentions [À VÉRIFIER] nécessitent validation avec données réelles.*
*Les commentaires 💬 expliquent les choix de données.*
