# Tontetic - Notes Projet

> **IMPORTANT**: Ce fichier contient les décisions et informations cruciales du projet.
> L'IA doit le lire au début de chaque session.

---

## 🚫 NE PAS FAIRE

| Interdit | Raison |
|----------|--------|
| Créer des plans sur Firebase | L'utilisateur a ses propres 4 plans |
| Ajouter des données de démo dans Firestore | Production-ready uniquement |
| Utiliser pravatar.cc ou URLs externes mockées | Supprimé lors de l'audit |
| Créer des collections Firestore non demandées | Demander confirmation avant |

---

## ✅ Plans Abonnement Users (Firestore `plans`)

| Nom | Type | Notes |
|-----|------|-------|
| **Gratuit** | user | Plan par défaut |
| **Starter** | user | - |
| **Standard** | user | - |
| **Premium** | user | - |

**NE PAS créer d'autres plans sans demande explicite.**

---

## 🔧 État Actuel du Projet

- **Audit Production-Ready**: ✅ Terminé (17/01/2026)
- **Déploiement**: https://tontetic-app.web.app
- **Firebase Project**: tontetic-admin

### Collections Firestore Utilisées
- `users` - Profils utilisateurs
- `tontines` - Cercles de tontine
- `plans` - Plans d'abonnement (4 plans users)
- `direct_messages` - Messages privés
- `kyc_requests` - Demandes KYC

### Firebase Storage
- `profile_photos/` - Photos de profil
- `kyc_documents/` - Documents KYC

---

## 📝 Historique des Décisions

| Date | Décision |
|------|----------|
| 17/01/2026 | Audit production-ready terminé - mocks supprimés |
| 17/01/2026 | 8 plans créés par erreur supprimés manuellement |
| 17/01/2026 | Fichier project_notes.md créé pour mémoire persistante |
| 17/01/2026 | Back Office Admin: RBAC implémenté, stats hardcodées supprimées |
| 17/01/2026 | Zero-Mock Final: guarantee_service + exit_circle_screen connectés Firestore |

---

## 💡 Préférences Utilisateur

- Header text color: **blanc** sur AppBar marineBlue
- Bottom navigation: **persistante** via MainShell
- Pas de popup welcome répétitif
- Confirmation avant toute modification Firebase

---

*Dernière mise à jour: 17/01/2026 15:36*
