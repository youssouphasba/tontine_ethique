import 'package:flutter/material.dart';

import 'package:tontetic/core/theme/app_theme.dart';

class LegalDocumentsScreen extends StatelessWidget {
  final int initialTabIndex;
  
  const LegalDocumentsScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Centre Légal & Conformité'),
          backgroundColor: AppTheme.marineBlue,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'CGU / CGV'),
              Tab(text: 'Politique Confidentialité'),
              Tab(text: 'Conditions Financières'),
              Tab(text: 'Offres Commerciales'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LegalTab(
              title: 'Conditions Générales d\'Utilisation',
              updatedAt: 'Mise à jour récente',
              content: '''
1. PRÉAMBULE
L'application Tontetic est une plateforme technique de mise en relation et de gestion de tontines. Tontetic N'EST PAS une banque ni un établissement de crédit.

2. GOUVERNANCE ET RÈGLE D'UNANIMITÉ
Pour garantir la sécurité de tous les membres, toute modification substantielle d'un cercle en cours (montant de la cotisation, nombre de participants, date de fin) requiert impérativement un VOTE À L'UNANIMITÉ (100%) des membres actifs.
- En cas de refus d'un seul membre, les conditions initiales prévalent jusqu'à la fin du cycle.
- Le départ anticipé d'un membre n'est autorisé que s'il propose un remplaçant validé par le cercle, ou s'il s'acquitte de la totalité de ses engagements restants.

3. RESPONSABILITÉ
L'utilisateur est seul responsable de la véracité des informations fournies (KYC). Tontetic ne saurait être tenu responsable des défauts de paiement entre membres au-delà de l'activation des mécanismes de garantie solidaire prévus par l'algorithme.

4. CONDITION D'ADHÉSION AUX CERCLES - FOLLOWERS MUTUELS
Pour garantir la confiance et la sécurité des cercles de tontine :

a) VISIBILITÉ DES CERCLES
Les cercles publics ne sont visibles que par les utilisateurs ayant une relation de "followers mutuels" avec le créateur du cercle. Une relation mutuelle signifie que les deux utilisateurs se suivent réciproquement.

b) CONDITIONS POUR REJOINDRE UN CERCLE
Pour rejoindre un cercle, l'utilisateur doit :
- Avoir un compte vérifié sur la plateforme
- Être en relation de followers mutuels avec le créateur du cercle
- Être approuvé par le créateur du cercle
- Signer le contrat d'engagement du cercle
- Connecter un moyen de paiement via un PSP agréé (Stripe, Wave, etc.)

c) INVITATION EXTERNE
Un créateur peut inviter des personnes non-inscrites par email ou téléphone. Dans ce cas :
- L'invité recevra un lien sécurisé d'invitation
- L'invité devra créer un compte et suivre le créateur
- Le créateur devra suivre l'invité en retour (relation mutuelle)
- Seulement après l'établissement de la relation mutuelle, l'invité pourra demander à rejoindre le cercle

d) VALIDATION PAR LE CRÉATEUR
Le créateur du cercle conserve le droit d'accepter ou refuser toute demande d'adhésion, même de la part de ses followers mutuels.

5. VOTE POUR L'ORDRE DES VERSEMENTS
Lorsque l'option "Vote des membres" est sélectionnée pour l'ordre des pots :
- Chaque membre soumet un classement unique et définitif
- L'ordre final est calculé selon la méthode de Borda (attribution de points par rang)
- Les votes sont horodatés et archivés de manière immuable
- Les votes peuvent être anonymes pour éviter toute pression sociale
- Tontetic ne peut pas modifier manuellement l'ordre après calcul
- En cas d'égalité, un tirage au sort départage les ex-æquo

6. GARANTIE SOLIDAIRE (AMANAH) - ACTIVATION 100% AUTOMATIQUE

a) PRINCIPE FONDAMENTAL
L'activation de la garantie est ENTIÈREMENT AUTOMATISÉE et repose EXCLUSIVEMENT sur des conditions objectives prévues au contrat de tontine.
La plateforme N'INTERVIENT À AUCUN MOMENT dans la décision, l'interprétation ou l'exécution financière.
AUCUN bouton, AUCUNE validation humaine, AUCUNE interprétation subjective.

b) MONTANT
Chaque membre signe un mandat SEPA de garantie conditionnelle égal à 1 cotisation. Cette garantie est une AUTORISATION, pas un prélèvement. Elle ne sera déclenchée qu'en cas de défaut avéré (3 tentatives échouées + 7 jours de grâce).

c) CONDITIONS D'ACTIVATION AUTOMATIQUE (liste exhaustive)
La garantie s'active automatiquement si ET SEULEMENT SI l'un des faits OBJECTIFS suivants est constaté :
- Cotisation non reçue après [X] jours de l'échéance (délai de grâce voté par le groupe)
- Solde PSP insuffisant après 3 tentatives automatiques de prélèvement
- Départ du cercle sans remplaçant validé
- Compte PSP suspendu ou rejet SEPA définitif

d) DÉLAI DE GRÂCE
Le groupe choisit un délai de grâce (3, 5 ou 7 jours) lors de la création du cercle.
Ce délai est inscrit au contrat et ne peut être modifié sans vote unanime.

e) PROCESSUS AUTOMATIQUE
- J+0 : Échéance de paiement
- J+1 : Notification automatique de retard au membre
- J+2 : Rappel automatique
- J+[délai de grâce] : Génération événement GUARANTEE_CONDITION_MET
- J+[délai de grâce] : Ordre technique envoyé au PSP
- J+[délai de grâce] : Notification automatique à tous les membres

f) RÔLE DE LA PLATEFORME
L'application OBSERVE les faits.
Le CONTRAT décide de l'activation.
Le PSP EXÉCUTE la redistribution.
La plateforme NE PEUT PAS :
- Appuyer sur un bouton "activer garantie"
- Valider ou refuser un cas
- Interpréter une situation
- Décider qui a tort ou raison

g) TRAÇABILITÉ ET PREUVE
Chaque événement est horodaté et journalisé de manière immuable :
- EventID unique
- Timestamp ISO 8601
- Condition contractuelle déclenchée
- Ordre PSP envoyé

h) REMBOURSEMENT
À la fin du cycle, si tous les paiements ont été honorés, la garantie est intégralement remboursée dans un délai de 7 jours ouvrés.

ANNEXE : MODALITÉS DES ABONNEMENTS
L'accès aux fonctionnalités de Tontetic est régi par quatre (4) formules d'abonnement :

1. PLAN GRATUIT
- Limite : 1 tontine active simultanée.
- Participants : 5 maximum par tontine.
- Support : Email & FAQ.

2. PLAN STARTER
- Limite : 2 tontines actives simultanées.
- Participants : 10 maximum par tontine.
- Support : Chat prioritaire.

3. PLAN STANDARD
- Limite : 3 tontines actives simultanées.
- Participants : 15 maximum par tontine.
- Support : Prioritaire complet.

4. PLAN PREMIUM
- Limite : 5 tontines actives simultanées.
- Participants : 20 maximum par tontine.
- Services + : Alertes intelligentes & IA Tontii prioritaire.
- Support : Accès premium dédié.

TRANSITIONS DE PLAN :
- Upgrade : Immédiat.
- Downgrade : Programmée pour le prochain cycle. Effectif seulement si l'usage respecte les limites du plan cible ou après validation exceptionnelle par le Support Client.
              ''',
            ),
            _LegalTab(
              title: 'Politique de Confidentialité (RGPD/APD)',
              updatedAt: 'Mise à jour récente',
              content: '''
1. COLLECTE DES DONNÉES
Nous collectons vos données d'identité (KYC), de contact et de transaction pour assurer le service.

2. MONÉTISATION ET TIERS
Dans le cadre de notre modèle "Freemium" et "Business" :
- Données Anonymisées : Nous pouvons agréger des statistiques de consommation (non nominatives) pour des partenaires.
- Marketplace & Publicité : Des offres ciblées peuvent vous être proposées si vous y avez consenti. Vous pouvez retirer ce consentement à tout moment dans les Paramètres.

3. SÉCURITÉ
Vos données sont chiffrées de bout en bout. L'accès aux logs sensibles est restreint aux administrateurs habilités via une double authentification.
              ''',
            ),
             _LegalTab(
              title: 'Conditions & Architecture Financière',
              updatedAt: 'Mise à jour récente',
              content: '''
1. ARCHITECTURE "SEPA PURE" (NON-CUSTODIAL)
Tontetic fonctionne selon un modèle strict de non-détention de fonds.
- Les fonds ne transitent JAMAIS par les comptes bancaires de Tontetic.
- Les transactions (cotisations, retraits) sont exécutées directement par nos partenaires PSP agréés (Wave, Orange Money, Stripe).
- Les comptes de cantonnement (Escrow) sont gérés EXCLUSIVEMENT par les PSP, PAS par Tontetic.

⚠️ CLARIFICATION ESCROW :
L'escrow mentionné est un compte technique géré par le PSP agréé (Stripe/Wave), conformément à leur licence d'établissement de paiement. Tontetic n'a AUCUN accès ni contrôle sur ces fonds.

2. RÔLE DE TONTETIC
Tontetic agit uniquement comme :
- Initiateur technique des ordres de paiement
- Interface de gestion et de suivi
- Outil de mise en relation

Tontetic ne reçoit, ne détient et ne gère AUCUN fond des utilisateurs.

3. FRAIS DE SERVICE
- Offre Gratuite : Frais de 1% par transaction, supportés par l'utilisateur et perçus par le PSP.
- Offre Premium : Abonnement mensuel fixe, transactions sans commissions pour l'utilisateur.
              ''',
            ),
            _LegalTab(
              title: 'Conditions Offre "Pionniers"',
              updatedAt: 'Mise à jour récente',
              content: '''
1. ÉLIGIBILITÉ
L'offre "Pionniers" est réservée exclusivement aux 20 premiers créateurs de cercles Starter et à leurs invités, à partir du 01/01/2026.

2. AVANTAGES
- Gratuité totale du forfait **Starter** pendant une période de trois (3) mois consécutifs.
- Accès aux limites du plan Starter (2 tontines, 10 participants, support prioritaire).
- Statut "Membre Fondateur" affiché sur le profil.
- Les invités du créateur bénéficient également de l'offre.

3. FIN DE PÉRIODE
Au terme des 3 mois offerts, le compte bascule automatiquement sur le paiement du forfait choisi au tarif en vigueur.

4. ABSENCE D'ASSURANCE
Cette offre ne constitue pas une assurance. La garantie Amanah est un mécanisme technique automatisé, pas un produit d'assurance.
              ''',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTab extends StatelessWidget {
  final String title;
  final String content;
  final String updatedAt;

  const _LegalTab({required this.title, required this.updatedAt, required this.content});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title, 
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text('Dernière mise à jour : $updatedAt', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        const Divider(height: 32),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
      ],
    );
  }
}
