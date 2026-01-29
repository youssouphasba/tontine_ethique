# 📋 Runbook Opérationnel - Tontetic

## Vue d'Ensemble

Ce document décrit les procédures opérationnelles pour la plateforme Tontetic.

---

## 1. Déploiement Production

### 1.1 Pré-requis
- [ ] Tous les tests passent (`flutter test`)
- [ ] Code review approuvée
- [ ] Version bumped dans `pubspec.yaml`
- [ ] Changelog mis à jour

### 1.2 Processus de Déploiement

```bash
# 1. Build production
flutter build apk --release
flutter build ios --release

# 2. Upload vers Firebase App Distribution
firebase appdistribution:distribute build/app/outputs/apk/release/app-release.apk \
  --app YOUR_APP_ID \
  --groups "beta-testers"

# 3. Rollout progressif
# Jour 1: 10% des utilisateurs
# Jour 3: 50% des utilisateurs
# Jour 7: 100% des utilisateurs
```

### 1.3 Vérifications Post-Déploiement
- [ ] Sentry sans nouvelles erreurs
- [ ] Métriques Firebase normales
- [ ] Webhooks PSP fonctionnels
- [ ] Tests de fumée manuels

---

## 2. Rollback

### 2.1 Critères de Rollback
- Erreur critique affectant >5% des utilisateurs
- Échec de paiement non résolu
- Fuite de données potentielle

### 2.2 Procédure de Rollback

```bash
# 1. Identifier la version stable
firebase appdistribution:releases:list --app YOUR_APP_ID

# 2. Rollback
firebase appdistribution:releases:rollback --app YOUR_APP_ID --version VERSION_CODE

# 3. Notifier les utilisateurs
# Via notification push et email
```

### 2.3 Post-Rollback
- [ ] Post-mortem dans les 24h
- [ ] RCA (Root Cause Analysis)
- [ ] Action items identifiés

---

## 3. Gestion des Incidents

### 3.1 Niveaux de Sévérité

| Niveau | Description | Temps de Réponse | Escalade |
|--------|-------------|------------------|----------|
| P1 | Indisponibilité totale | 15 min | Immédiate |
| P2 | Paiements bloqués | 30 min | 1h |
| P3 | Fonctionnalité dégradée | 2h | 4h |
| P4 | Bug mineur | 24h | N/A |

### 3.2 Processus d'Incident

1. **Détection** : Alertes Sentry / Monitoring / Utilisateur
2. **Qualification** : Déterminer la sévérité (P1-P4)
3. **Communication** : Informer les parties prenantes
4. **Mitigation** : Actions immédiates pour limiter l'impact
5. **Résolution** : Fix et déploiement
6. **Post-mortem** : Analyse dans les 48h

### 3.3 Contacts d'Urgence

| Rôle | Contact | Disponibilité |
|------|---------|---------------|
| On-call | PagerDuty | 24/7 |
| Tech Lead | [REDACTED] | 9h-22h |
| CTO | [REDACTED] | Escalade P1 |
| Support PSP Stripe | support@stripe.com | 24/7 |
| Support PSP Wave | support@wave.com | 24/7 |

---

## 4. Maintenance Planifiée

### 4.1 Fenêtres de Maintenance
- **Préférée** : Dimanche 2h-5h (UTC+0)
- **Secondaire** : Mercredi 2h-4h (UTC+0)

### 4.2 Checklist Maintenance

#### Avant
- [ ] Notification envoyée 48h avant
- [ ] Backup base de données
- [ ] Plan de rollback prêt

#### Pendant
- [ ] Page de maintenance active
- [ ] Logs de toutes les actions
- [ ] Tests post-modification

#### Après
- [ ] Vérification services
- [ ] Notification fin de maintenance
- [ ] Monitoring renforcé 24h

---

## 5. Sécurité

### 5.1 Gestion des Secrets

```bash
# Ne JAMAIS commiter les secrets
# Utiliser les variables d'environnement

# Rotation des clés (trimestrielle)
1. Générer nouvelle clé dans Stripe Dashboard
2. Mettre à jour .env en production
3. Tester les webhooks
4. Révoquer l'ancienne clé
```

### 5.2 Accès Production

| Qui | Accès | Conditions |
|-----|-------|------------|
| Tech Lead | Full | MFA requis |
| Dev Senior | Logs + Monitoring | MFA requis |
| Support | Dashboard admin | MFA requis |
| Dev Junior | Aucun | Via Tech Lead |

### 5.3 Procédure de Breach

1. **Isoler** : Couper l'accès compromis
2. **Préserver** : Sauvegarder les logs
3. **Analyser** : Déterminer l'étendue
4. **Notifier** : CNIL dans les 72h si données perso
5. **Remédier** : Patcher et renforcer
6. **Communiquer** : Informer les utilisateurs si nécessaire

---

## 6. Monitoring

### 6.1 Métriques Clés

| Métrique | Seuil Alerte | Seuil Critique |
|----------|--------------|----------------|
| Error Rate | >1% | >5% |
| Latency P95 | >500ms | >2000ms |
| Webhook Failures | >2/heure | >10/heure |
| Login Failures | >10/min | >50/min |

### 6.2 Dashboards

- **Sentry** : Erreurs et crashes
- **Firebase** : Analytics utilisateurs
- **Stripe Dashboard** : Paiements
- **Supabase** : Base de données

---

## 7. Réconciliation Financière

### 7.1 Réconciliation Quotidienne

```
1. Exporter transactions Stripe (J-1)
2. Comparer avec logs internes
3. Identifier écarts > 1€
4. Investiguer et corriger
5. Logger les corrections
```

### 7.2 Réconciliation Mensuelle

- Rapport complet PSP vs interne
- Vérification des commissions
- Validation des reversements
- Archivage pour audit

---

## 8. Backup & Recovery

### 8.1 Backups Automatiques

| Données | Fréquence | Rétention |
|---------|-----------|-----------|
| Base Supabase | Quotidien | 30 jours |
| Logs audit | Quotidien | 5 ans |
| Config | Chaque commit | Infini (Git) |

### 8.2 Procédure de Recovery

```bash
# 1. Identifier le point de restauration
supabase db restore --point-in-time "2026-01-05T00:00:00Z"

# 2. Vérifier l'intégrité
flutter test

# 3. Synchroniser les PSP
# Vérifier manuellement les transactions depuis le restore point
```

---

## 9. Conformité

### 9.1 Checklist RGPD Mensuelle

- [ ] Demandes d'export traitées (<30j)
- [ ] Demandes de suppression traitées (<30j)
- [ ] Consentements à jour
- [ ] Logs anonymisés après délai légal

### 9.2 Checklist PSP Trimestrielle

- [ ] Webhooks fonctionnels
- [ ] Clés API rotées
- [ ] Réconciliation sans écarts
- [ ] Certificats SSL valides

---

## 10. Contacts Utiles

| Service | Contact | Usage |
|---------|---------|-------|
| Stripe Support | stripe.com/support | Paiements |
| Wave Support | wave.com/support | Paiements FCFA |
| Supabase Support | supabase.com/support | BDD |
| Firebase Support | firebase.google.com/support | App |
| CNIL | cnil.fr | RGPD |

---

*Dernière mise à jour : 2026-01-06*
