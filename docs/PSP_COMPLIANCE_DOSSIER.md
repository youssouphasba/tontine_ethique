# 📋 Dossier de Conformité PSP - Tontetic

## 1. Présentation de la Plateforme

### 1.1 Identité
- **Raison sociale** : Tontetic SAS
- **Activité** : Plateforme de gestion de tontines numériques
- **Statut réglementaire** : Hébergeur technique (LCEN Art.6)
- **Contact conformité** : compliance@tontetic.io

### 1.2 Modèle Économique

```
┌─────────────────────────────────────────────────────────────────┐
│                     ARCHITECTURE FINANCIÈRE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   UTILISATEUR ──────► PSP (Stripe/Wave) ──────► BÉNÉFICIAIRE    │
│        │                     │                                   │
│        │                     │                                   │
│        ▼                     ▼                                   │
│   ┌─────────┐         ┌───────────┐                             │
│   │ TONTETIC│◄────────│ WEBHOOKS  │                             │
│   │ (Lecture│         │ (Lecture) │                             │
│   │  Seule) │         └───────────┘                             │
│   └─────────┘                                                    │
│                                                                  │
│   ⚠️ TONTETIC NE DÉTIENT JAMAIS LES FONDS                      │
│   ⚠️ TONTETIC NE PEUT PAS INITIER DE VIREMENTS                 │
│   ⚠️ TOUTES LES OPÉRATIONS SONT PSP → PSP                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Raisons de Non-Agrément EME

| Critère | Statut | Justification |
|---------|--------|---------------|
| Détention de fonds | ❌ Non | Fonds sur comptes PSP |
| Émission de monnaie | ❌ Non | Pas de tokens/points |
| Exécution de paiements | ❌ Non | PSP exécute tout |
| Gestion de comptes | ❌ Non | Comptes = comptes PSP |
| Transferts de fonds | ❌ Non | PSP → PSP uniquement |

---

## 2. PSPs Intégrés

### 2.1 Stripe (Zone Euro)
- **Licence** : EME (E-Money Institution)
- **Régulateur** : Central Bank of Ireland
- **Services utilisés** :
  - Stripe Connect (comptes marchands)
  - Stripe Payment Intents
  - Webhooks signés

### 2.2 Wave (Zone FCFA)
- **Licence** : EME (établissement de monnaie électronique)
- **Régulateur** : BCEAO
- **Services utilisés** :
  - Wave Business API
  - Webhooks signés

---

## 3. Architecture de Sécurité

### 3.1 Les 6 Piliers

| Pilier | Description | Implémentation |
|--------|-------------|----------------|
| **Authentification** | Mots de passe forts + 2FA | Supabase Auth + Biométrie |
| **Autorisation** | RBAC granulaire | AdminPermissionService |
| **Sécurité Financière** | Idempotence + validation | FinancialSecurityPillar |
| **Protection API** | Rate limiting | RateLimitService |
| **Auditabilité** | Logs immuables | PersistentAuditService |
| **Réponse Incidents** | Procédures documentées | RUNBOOK.md |

### 3.2 Flux de Données

```
┌──────────────────────────────────────────────────────────────┐
│                    FLUX DE PAIEMENT                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Utilisateur initie cotisation dans l'app                │
│                      │                                        │
│                      ▼                                        │
│  2. App redirige vers checkout PSP (Stripe/Wave)            │
│                      │                                        │
│                      ▼                                        │
│  3. Utilisateur paye directement au PSP                      │
│                      │                                        │
│                      ▼                                        │
│  4. PSP notifie Tontetic via webhook signé                   │
│                      │                                        │
│                      ▼                                        │
│  5. Tontetic valide signature + met à jour l'affichage       │
│                      │                                        │
│                      ▼                                        │
│  6. À la fin du cycle, PSP verse au bénéficiaire            │
│     (ordonnancé par Tontetic, exécuté par PSP)               │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Conformité RGPD

### 4.1 Données Collectées

| Donnée | Finalité | Base Légale | Durée |
|--------|----------|-------------|-------|
| Email | Identification | Contrat | Compte actif + 5 ans |
| Téléphone | Authentification | Contrat | Compte actif + 5 ans |
| Nom | Identification | Contrat | Compte actif + 5 ans |
| Transactions | Exécution tontine | Contrat | 5 ans (LCB-FT) |
| Mandats SEPA | Prélèvements | Contrat | 10 ans |
| Logs | Sécurité/Audit | Intérêt légitime | 5 ans |

### 4.2 Droits des Utilisateurs

| Droit | Implémentation | Délai |
|-------|----------------|-------|
| Accès (Art.15) | GDPRService.exportUserData() | 30 jours |
| Rectification (Art.16) | Profil utilisateur | Immédiat |
| Effacement (Art.17) | GDPRService.requestDeletion() | 30 jours |
| Portabilité (Art.20) | Export JSON | 30 jours |

### 4.3 DPO
- **Contact** : dpo@tontetic.io
- **Déclaration CNIL** : [Numéro à compléter]

---

## 5. Lutte Anti-Blanchiment (LCB-FT)

### 5.1 Mesures Implémentées

| Mesure | Description |
|--------|-------------|
| **Plafonds** | 500€/mois (325 000 FCFA) par utilisateur |
| **KYC** | Vérification email + téléphone |
| **Monitoring** | Détection comportements anormaux |
| **Signalement** | Procédure de déclaration TRACFIN |

### 5.2 Obligations Déclaratives

- TRACFIN : Via procédure documentée
- Gel des avoirs : Vérification liste sanctions UE

---

## 6. Documentation Technique

### 6.1 Webhooks

| Endpoint | Signature | Retry |
|----------|-----------|-------|
| /webhooks/stripe | HMAC-SHA256 | 3x avec backoff |
| /webhooks/wave | HMAC-SHA256 | 3x avec backoff |

### 6.2 Logs d'Audit

- **Format** : JSON avec hash chain
- **Stockage** : Supabase (UE)
- **Rétention** : 5 ans
- **Export** : Disponible à la demande

---

## 7. Tests et Audits

### 7.1 Tests de Sécurité

| Type | Fréquence | Dernier |
|------|-----------|---------|
| Tests unitaires | CI/CD | Chaque commit |
| Tests d'intégration | Hebdomadaire | 2026-01-06 |
| Pentest externe | Annuel | À planifier |

### 7.2 Certifications

| Certification | Statut | Date prévue |
|---------------|--------|-------------|
| ISO 27001 | 📋 Planifié | 2026 Q4 |
| PCI-DSS | ✅ Délégué | Via Stripe |
| SOC 2 | 📋 Planifié | 2027 Q1 |

---

## 8. Contacts

| Rôle | Contact |
|------|---------|
| **Conformité** | compliance@tontetic.io |
| **DPO** | dpo@tontetic.io |
| **Juridique** | legal@tontetic.io |
| **Technique** | tech@tontetic.io |
| **Support** | support@tontetic.io |

---

## 9. Pièces Jointes

- [ ] CGU en vigueur (version datée)
- [ ] Politique de confidentialité
- [ ] Contrats PSP (extraits non-confidentiels)
- [ ] Schéma d'architecture
- [ ] Rapport de conformité RGPD
- [ ] Procédure TRACFIN

---

*Document préparé le : 2026-01-06*
*Version : 1.0*
*Prochaine révision : 2026-04-06*
