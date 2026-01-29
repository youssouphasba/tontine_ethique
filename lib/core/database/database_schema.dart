/// Database Schema for Financial Back-Office
/// 
/// RÈGLES FONDAMENTALES:
/// - user_payment_events: LECTURE SEULE, aucune écriture manuelle
/// - audit_ledger: IMMUTABLE, pas d'UPDATE, pas de DELETE
/// - Jamais calculer: solde utilisateur, total argent cercle, fonds détenus
///
/// 11 Tables définies selon spécifications conformité
library;


// ============================================================
// ENUMS
// ============================================================

enum UserType { particulier, salarie, marchand, entreprise }
enum UserStatus { actif, suspendu, cloture }

enum CompanyFormula { starterPro, teamPro, departement, entreprise }
enum SubscriptionStatus { active, unpaid, canceled }

enum TransactionType { abonnement, boost, option }
enum TransactionStatus { paid, failed, refunded }

enum PaymentEventType { authorization, debit, rejection }

enum CircleType { prive, restreint }
enum CircleStatus { enCreation, actif, cloture }

enum GuaranteeStatus { bloquee, liberee, utilisee }
enum GuaranteeTriggerType { automatique, defautConstate }

enum RewardType { cash, bon, credit }
enum RewardStatus { pending, eligible, paid }
enum PayoutMethod { externalLink, psp }

enum KycStatus { nonRequis, validePsp }

enum AuditSource { system, admin }

enum PaymentProvider { stripe, paypal, wave, orangeMoney, autre }

// ============================================================
// A. USERS - Données minimales, pas financières
// ============================================================

class UserRecord {
  final String id;
  final UserType typeUser;
  final UserStatus status;
  final String pays;
  final DateTime createdAt;
  final DateTime? deletedAt;  // Soft delete

  const UserRecord({
    required this.id,
    required this.typeUser,
    required this.status,
    required this.pays,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type_user': typeUser.name,
    'status': status.name,
    'pays': pays,
    'created_at': createdAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };
}

// ============================================================
// B. COMPANIES
// ============================================================

class CompanyRecord {
  final String id;
  final String raisonSociale;
  final String pays;
  final CompanyFormula typeFormule;
  final SubscriptionStatus statutAbonnement;
  final DateTime createdAt;

  const CompanyRecord({
    required this.id,
    required this.raisonSociale,
    required this.pays,
    required this.typeFormule,
    required this.statutAbonnement,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'raison_sociale': raisonSociale,
    'pays': pays,
    'type_formule': typeFormule.name,
    'statut_abonnement': statutAbonnement.name,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================
// C. SUBSCRIPTIONS - Revenus plateforme uniquement
// ============================================================

class SubscriptionRecord {
  final String id;
  final String entityType;  // user / company
  final String entityId;
  final String formule;
  final double montantHt;
  final double tva;
  final double montantTtc;
  final String devise;
  final PaymentProvider psp;
  final String pspSubscriptionId;
  final SubscriptionStatus status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime createdAt;

  const SubscriptionRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.formule,
    required this.montantHt,
    required this.tva,
    required this.montantTtc,
    required this.devise,
    required this.psp,
    required this.pspSubscriptionId,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity_type': entityType,
    'entity_id': entityId,
    'formule': formule,
    'montant_ht': montantHt,
    'tva': tva,
    'montant_ttc': montantTtc,
    'devise': devise,
    'psp': psp.name,
    'psp_subscription_id': pspSubscriptionId,
    'status': status.name,
    'period_start': periodStart.toIso8601String(),
    'period_end': periodEnd.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================
// D. PLATFORM_TRANSACTIONS - TON argent seulement
// ============================================================

class PlatformTransactionRecord {
  final String id;
  final TransactionType type;
  final String entityType;  // company / merchant
  final String entityId;
  final double montantHt;
  final double tva;
  final double montantTtc;
  final String devise;
  final PaymentProvider psp;
  final String pspPaymentId;
  final TransactionStatus status;
  final String? invoiceId;
  final DateTime createdAt;

  const PlatformTransactionRecord({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.montantHt,
    required this.tva,
    required this.montantTtc,
    required this.devise,
    required this.psp,
    required this.pspPaymentId,
    required this.status,
    this.invoiceId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'entity_type': entityType,
    'entity_id': entityId,
    'montant_ht': montantHt,
    'tva': tva,
    'montant_ttc': montantTtc,
    'devise': devise,
    'psp': psp.name,
    'psp_payment_id': pspPaymentId,
    'status': status.name,
    'invoice_id': invoiceId,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================
// E. USER_PAYMENT_EVENTS - LECTURE SEULE
// ⚠️ Argent des utilisateurs – jamais modifiable
// ⚠️ Aucune écriture manuelle autorisée
// ============================================================

class UserPaymentEventRecord {
  final String id;
  final String userId;
  final String circleId;
  final PaymentEventType eventType;
  final double montant;
  final String devise;
  final PaymentProvider psp;
  final String pspEventId;
  final String status;
  final DateTime occurredAt;

  /// ⚠️ LECTURE SEULE - Cette classe ne doit JAMAIS être modifiée manuellement
  /// Seules les notifications PSP peuvent créer des entrées
  const UserPaymentEventRecord({
    required this.id,
    required this.userId,
    required this.circleId,
    required this.eventType,
    required this.montant,
    required this.devise,
    required this.psp,
    required this.pspEventId,
    required this.status,
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'circle_id': circleId,
    'event_type': eventType.name,
    'montant': montant,
    'devise': devise,
    'psp': psp.name,
    'psp_event_id': pspEventId,
    'status': status,
    'occurred_at': occurredAt.toIso8601String(),
  };
}

// ============================================================
// F. CIRCLES
// ============================================================

class CircleRecord {
  final String id;
  final CircleType type;
  final double montantPeriodique;
  final String periodicite;
  final int nombreMembres;
  final CircleStatus statut;
  final String createdBy;
  final DateTime createdAt;

  const CircleRecord({
    required this.id,
    required this.type,
    required this.montantPeriodique,
    required this.periodicite,
    required this.nombreMembres,
    required this.statut,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'montant_periodique': montantPeriodique,
    'periodicite': periodicite,
    'nombre_membres': nombreMembres,
    'statut': statut.name,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================
// G. GUARANTEES
// ============================================================

class GuaranteeRecord {
  final String id;
  final String circleId;
  final String userId;
  final double montant;
  final GuaranteeStatus status;
  final GuaranteeTriggerType triggerType;
  final String pspReference;
  final DateTime? triggeredAt;

  const GuaranteeRecord({
    required this.id,
    required this.circleId,
    required this.userId,
    required this.montant,
    required this.status,
    required this.triggerType,
    required this.pspReference,
    this.triggeredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'circle_id': circleId,
    'user_id': userId,
    'montant': montant,
    'status': status.name,
    'trigger_type': triggerType.name,
    'psp_reference': pspReference,
    'triggered_at': triggeredAt?.toIso8601String(),
  };
}

// ============================================================
// H. REFERRAL_REWARDS
// ============================================================

class ReferralRewardRecord {
  final String id;
  final String referrerUserId;
  final String referredUserId;
  final RewardType rewardType;
  final double montant;
  final RewardStatus status;
  final PayoutMethod payoutMethod;
  final DateTime createdAt;
  final DateTime? paidAt;

  const ReferralRewardRecord({
    required this.id,
    required this.referrerUserId,
    required this.referredUserId,
    required this.rewardType,
    required this.montant,
    required this.status,
    required this.payoutMethod,
    required this.createdAt,
    this.paidAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'referrer_user_id': referrerUserId,
    'referred_user_id': referredUserId,
    'reward_type': rewardType.name,
    'montant': montant,
    'status': status.name,
    'payout_method': payoutMethod.name,
    'created_at': createdAt.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
  };
}

// ============================================================
// I. MERCHANT_ACCOUNTS
// ============================================================

class MerchantAccountRecord {
  final String id;
  final String userId;
  final String status;  // actif / suspendu
  final String pays;
  final KycStatus kycStatus;
  final DateTime createdAt;

  const MerchantAccountRecord({
    required this.id,
    required this.userId,
    required this.status,
    required this.pays,
    required this.kycStatus,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'status': status,
    'pays': pays,
    'kyc_status': kycStatus.name,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================
// J. MERCHANT_BOOSTS
// ============================================================

class MerchantBoostRecord {
  final String id;
  final String merchantId;
  final String produitId;
  final double montant;
  final String devise;
  final String pspPaymentId;
  final String status;
  final DateTime startDate;
  final DateTime endDate;

  const MerchantBoostRecord({
    required this.id,
    required this.merchantId,
    required this.produitId,
    required this.montant,
    required this.devise,
    required this.pspPaymentId,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant_id': merchantId,
    'produit_id': produitId,
    'montant': montant,
    'devise': devise,
    'psp_payment_id': pspPaymentId,
    'status': status,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
  };
}

// ============================================================
// K. AUDIT_LEDGER - IMMUTABLE
// ❌ pas d'UPDATE
// ❌ pas de DELETE
// ============================================================

class AuditLedgerRecord {
  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String description;
  final AuditSource source;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  /// IMMUTABLE - Cette classe ne doit JAMAIS être modifiée ou supprimée
  const AuditLedgerRecord({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.description,
    required this.source,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_type': eventType,
    'entity_type': entityType,
    'entity_id': entityId,
    'description': description,
    'source': source.name,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'created_at': createdAt.toIso8601String(),
  };
}

// ============================================================
// SQL SCHEMA GENERATION
// ============================================================

class DatabaseSchemaGenerator {
  static String generatePostgreSql() {
    return '''
-- ============================================================
-- FINANCIAL BACK-OFFICE DATABASE SCHEMA
-- Generated: ${DateTime.now().toIso8601String()}
-- ============================================================

-- A. USERS (Données minimales, pas financières)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_user VARCHAR(20) NOT NULL CHECK (type_user IN ('particulier', 'salarie', 'marchand', 'entreprise')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('actif', 'suspendu', 'cloture')),
    pays VARCHAR(3) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL  -- Soft delete
);

-- B. COMPANIES
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raison_sociale VARCHAR(255) NOT NULL,
    pays VARCHAR(3) NOT NULL,
    type_formule VARCHAR(20) NOT NULL CHECK (type_formule IN ('starter_pro', 'team_pro', 'departement', 'entreprise')),
    statut_abonnement VARCHAR(20) NOT NULL CHECK (statut_abonnement IN ('active', 'unpaid', 'canceled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- C. SUBSCRIPTIONS (Revenus plateforme uniquement)
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('user', 'company')),
    entity_id UUID NOT NULL,
    formule VARCHAR(50) NOT NULL,
    montant_ht DECIMAL(15,2) NOT NULL,
    tva DECIMAL(15,2) NOT NULL,
    montant_ttc DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    psp VARCHAR(20) NOT NULL,
    psp_subscription_id VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'unpaid', 'canceled')),
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- D. PLATFORM_TRANSACTIONS (TON argent seulement)
CREATE TABLE platform_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('abonnement', 'boost', 'option')),
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('company', 'merchant')),
    entity_id UUID NOT NULL,
    montant_ht DECIMAL(15,2) NOT NULL,
    tva DECIMAL(15,2) NOT NULL,
    montant_ttc DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    psp VARCHAR(20) NOT NULL,
    psp_payment_id VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('paid', 'failed', 'refunded')),
    invoice_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- E. USER_PAYMENT_EVENTS (LECTURE SEULE - Argent des utilisateurs)
-- ⚠️ AUCUNE ÉCRITURE MANUELLE AUTORISÉE
CREATE TABLE user_payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    circle_id UUID NOT NULL,
    event_type VARCHAR(20) NOT NULL CHECK (event_type IN ('authorization', 'debit', 'rejection')),
    montant DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    psp VARCHAR(20) NOT NULL,
    psp_event_id VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL
);
-- Revoke INSERT/UPDATE/DELETE for all users except system
-- REVOKE INSERT, UPDATE, DELETE ON user_payment_events FROM PUBLIC;

-- F. CIRCLES
CREATE TABLE circles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('prive', 'restreint')),
    montant_periodique DECIMAL(15,2) NOT NULL,
    periodicite VARCHAR(20) NOT NULL,
    nombre_membres INTEGER NOT NULL,
    statut VARCHAR(20) NOT NULL CHECK (statut IN ('en_creation', 'actif', 'cloture')),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- G. GUARANTEES
CREATE TABLE guarantees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES circles(id),
    user_id UUID NOT NULL REFERENCES users(id),
    montant DECIMAL(15,2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('bloquee', 'liberee', 'utilisee')),
    trigger_type VARCHAR(30) NOT NULL CHECK (trigger_type IN ('automatique', 'defaut_constate')),
    psp_reference VARCHAR(255) NOT NULL,
    triggered_at TIMESTAMP WITH TIME ZONE
);

-- H. REFERRAL_REWARDS
CREATE TABLE referral_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_user_id UUID NOT NULL REFERENCES users(id),
    referred_user_id UUID NOT NULL REFERENCES users(id),
    reward_type VARCHAR(20) NOT NULL CHECK (reward_type IN ('cash', 'bon', 'credit')),
    montant DECIMAL(15,2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'eligible', 'paid')),
    payout_method VARCHAR(20) NOT NULL CHECK (payout_method IN ('external_link', 'psp')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- I. MERCHANT_ACCOUNTS
CREATE TABLE merchant_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL CHECK (status IN ('actif', 'suspendu')),
    pays VARCHAR(3) NOT NULL,
    kyc_status VARCHAR(20) NOT NULL CHECK (kyc_status IN ('non_requis', 'valide_psp')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- J. MERCHANT_BOOSTS
CREATE TABLE merchant_boosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchant_accounts(id),
    produit_id UUID NOT NULL,
    montant DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    psp_payment_id VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL
);

-- K. AUDIT_LEDGER (IMMUTABLE - Table la plus importante juridiquement)
-- ❌ pas d'UPDATE
-- ❌ pas de DELETE
CREATE TABLE audit_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    description TEXT NOT NULL,
    source VARCHAR(20) NOT NULL CHECK (source IN ('system', 'admin')),
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Protect audit_ledger from modifications
CREATE RULE protect_audit_update AS ON UPDATE TO audit_ledger DO INSTEAD NOTHING;
CREATE RULE protect_audit_delete AS ON DELETE TO audit_ledger DO INSTEAD NOTHING;

-- ============================================================
-- INDEXES
-- ============================================================
-- RÈGLES GÉNÉRALES:
-- - Indexer ce qui est filtré, joint, trié
-- - Jamais d'index sur champs sensibles non utilisés
-- - Tables d'audit et d'événements → index lecture rapide, pas écriture
-- - "Toute table liée à l'argent doit être indexée pour lecture, jamais pour calcul."

-- ============================================================
-- 1️⃣ USERS (segmentation + conformité)
-- ============================================================
CREATE INDEX idx_users_type ON users(type_user);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_country ON users(pays);
CREATE INDEX idx_users_created_at ON users(created_at);

-- ============================================================
-- 2️⃣ COMPANIES
-- ============================================================
CREATE INDEX idx_companies_country ON companies(pays);
CREATE INDEX idx_companies_plan ON companies(type_formule);
CREATE INDEX idx_companies_status ON companies(statut_abonnement);

-- ============================================================
-- 3️⃣ SUBSCRIPTIONS (KPI MRR / churn / PSP)
-- ============================================================
CREATE INDEX idx_subscriptions_entity ON subscriptions(entity_type, entity_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_period ON subscriptions(period_start, period_end);
CREATE INDEX idx_subscriptions_psp ON subscriptions(psp);

-- ============================================================
-- 4️⃣ PLATFORM_TRANSACTIONS (COMPTA PURE - TVA, facturation, audit)
-- ============================================================
CREATE INDEX idx_platform_tx_type ON platform_transactions(type);
CREATE INDEX idx_platform_tx_entity ON platform_transactions(entity_type, entity_id);
CREATE INDEX idx_platform_tx_status ON platform_transactions(status);
CREATE INDEX idx_platform_tx_created ON platform_transactions(created_at);
CREATE INDEX idx_platform_tx_psp ON platform_transactions(psp);

-- ============================================================
-- 5️⃣ USER_PAYMENT_EVENTS (⚠️ LECTURE SEULE - pas de jointures lourdes)
-- ============================================================
CREATE INDEX idx_user_events_user ON user_payment_events(user_id);
CREATE INDEX idx_user_events_circle ON user_payment_events(circle_id);
CREATE INDEX idx_user_events_type ON user_payment_events(event_type);
CREATE INDEX idx_user_events_status ON user_payment_events(status);
CREATE INDEX idx_user_events_occurred ON user_payment_events(occurred_at);

-- ============================================================
-- 6️⃣ CIRCLES
-- ============================================================
CREATE INDEX idx_circles_creator ON circles(created_by);
CREATE INDEX idx_circles_status ON circles(statut);
CREATE INDEX idx_circles_type ON circles(type);
CREATE INDEX idx_circles_created ON circles(created_at);

-- ============================================================
-- 7️⃣ GUARANTEES (preuve juridique en cas de litige)
-- ============================================================
CREATE INDEX idx_guarantees_circle ON guarantees(circle_id);
CREATE INDEX idx_guarantees_user ON guarantees(user_id);
CREATE INDEX idx_guarantees_status ON guarantees(status);
CREATE INDEX idx_guarantees_trigger ON guarantees(trigger_type);

-- ============================================================
-- 8️⃣ REFERRAL_REWARDS
-- ============================================================
CREATE INDEX idx_referrals_referrer ON referral_rewards(referrer_user_id);
CREATE INDEX idx_referrals_status ON referral_rewards(status);
CREATE INDEX idx_referrals_paid ON referral_rewards(paid_at);

-- ============================================================
-- 9️⃣ MERCHANT_ACCOUNTS
-- ============================================================
CREATE INDEX idx_merchants_user ON merchant_accounts(user_id);
CREATE INDEX idx_merchants_status ON merchant_accounts(status);
CREATE INDEX idx_merchants_country ON merchant_accounts(pays);

-- ============================================================
-- 🔟 MERCHANT_BOOSTS
-- ============================================================
CREATE INDEX idx_boosts_merchant ON merchant_boosts(merchant_id);
CREATE INDEX idx_boosts_status ON merchant_boosts(status);
CREATE INDEX idx_boosts_dates ON merchant_boosts(start_date, end_date);

-- ============================================================
-- 1️⃣1️⃣ AUDIT_LEDGER (CRITIQUE - lecture rapide)
-- ⚠️ Ne jamais indexer la description
-- ⚠️ Pas de DELETE / UPDATE
-- ============================================================
CREATE INDEX idx_audit_entity ON audit_ledger(entity_type, entity_id);
CREATE INDEX idx_audit_event ON audit_ledger(event_type);
CREATE INDEX idx_audit_created ON audit_ledger(created_at);

-- ============================================================
-- 1️⃣2️⃣ INDEX UNIQUES (ANTI-FRAUDE)
-- ============================================================
CREATE UNIQUE INDEX uniq_psp_event ON user_payment_events(psp_event_id);
CREATE UNIQUE INDEX uniq_platform_tx_psp ON platform_transactions(psp_payment_id);
CREATE UNIQUE INDEX uniq_subscription_psp ON subscriptions(psp_subscription_id);
''';
  }
}
