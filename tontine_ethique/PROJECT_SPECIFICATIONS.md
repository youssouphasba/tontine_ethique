# PROJET TONTETIC : Spécifications Techniques & Fonctionnelles

Ce document résume l'architecture, les règles métier et l'identité de l'application **Tontetic**.

---

## 1. Identité Visuelle

*   **Nom** : Tontetic (Tontine Éthique)
*   **Palette de Couleurs** :
    *   🔵 **Bleu Marine** (Dominant) : `#0A192F` - Confiance, Sécurité, Premium.
    *   🟡 **Or** (Accents) : `#D4AF37` - Richesse, Succès, Valeur.
    *   🔴 **Rouge** (Alerte) : `#D32F2F` - Erreurs, Exclusions, Danger.
    *   ⚪ **Off-White** (Fond) : `#FAFAFA` - Clarté, Modernité.
*   **Typographie** :
    *   Titres : **Montserrat** (Moderne, Géométrique).
    *   Corps : **Lato** (Lisible, Élégant).

---

## 2. Modèle Économique

L'application repose sur un modèle "Freemium" adapté aux deux zones géographiques cibles.

*   **Zone Euro (France...)** : Abonnement à partir de **2,99 € / mois** (Starter).
*   **Zone FCFA (Sénégal...)** : Abonnement à partir de **2 000 FCFA / mois**.

**Avantages Premium** :
*   Accès aux paliers de cotisation élevés.
*   Nombre de cercles illimité.
*   Badge "Membre Privilégié" (Gold).
*   Support prioritaire.

---

## 3. Grille des Paliers & Cotisations

Les montants de cotisation sont strictement encadrés pour assurer la sécurité financière des groupes.

### Zone FCFA (XOF)
| Statut Utilisateur | Paliers Autorisés (FCFA) | Action Si Dépassement |
| :--- | :--- | :--- |
| **Gratuit** | 10k, 20k, 30k | Bloqué (Invitation au Premium) |
| **Premium** | 50k, 100k, 200k, 300k, 500k | Autorisé |
| **Tous** | > 500k | **Validation Admin Requise** |

### Zone Euro (€)
| Statut Utilisateur | Paliers Autorisés (€) | Action Si Dépassement |
| :--- | :--- | :--- |
| **Gratuit** | 30€, 50€, 70€ | Bloqué (Invitation au Premium) |
| **Premium** | 100€, 200€, 300€, 400€, 500€ | Autorisé |
| **Tous** | > 500€ | **Validation Admin Requise** |

---

## 4. Sécurité & Garantie Solidaire

### Limitation des Participants
*   **Standard** : Jusqu'à **5 personnes** (Création immédiate).
*   **Sécurité Renforcée** : **6 personnes et plus** nécessitent une **Validation Admin** manuelle pour vérifier la cohésion du groupe.

### Garantie Solidaire & Mandat SEPA
Tontetic remplace l'assurance traditionnelle par une **Garantie Solidaire**.
*   **Mécanisme** : Signature d'un mandat SEPA (ou équivalent Mobile Money) servant de promesse de paiement.
*   **Principe** : Aucun prélèvement immédiat. Le mandat n'est activé que par l'Admin en cas de défaillance avérée, pour assurer la continuité du cycle pour les autres membres.
*   **Message Membre** : *"Votre argent reste sur votre compte, mais votre cercle est protégé. C’est cela, la finance éthique et solidaire."*

### Épargne Bloquée
*   Module permettant de bloquer une somme jusqu'à une date précise.
*   **Sécurité** : Retrait impossible avant l'échéance sans contacter le support.

---

## 5. Administration & Modération

L'administrateur Tontetic dispose de pouvoirs étendus pour protéger la communauté :

1.  **Validation des Cercles** :
    *   Approbation manuelle des tontines à hauts montants (>500€/500k).
    *   Approbation manuelle des grands groupes (>5 pers).
2.  **Gestion des Membres (Exclusion)** :
    *   Possibilité d'**exclure un membre** d'un cercle (Bouton Rouge).
    *   **Traçabilité** : Obligation de sélectionner un motif légal (Incapacité, Fraude, Non-respect) pour les logs.
    *   **Clôture Financière** : Calcul immédiat du solde (Versé vs Reçu) et choix de l'option de régularisation (Transfert de dette ou Remboursement).
3.  **Déblocage d'Épargne** : Intervention manuelle pour débloquer une épargne en cas d'urgence absolue.

---

## 6. Éthique & Conformité

*   **Zéro Intérêt (No Riba)** : Strictement aucun mécanisme d'intérêt, d'usure ou de spéculation. Le modèle est basé sur des frais de service fixes et transparents.
*   transparence totale sur les frais de fonctionnement.
*   Approche communautaire et solidaire.
