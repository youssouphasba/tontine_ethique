const admin = require('firebase-admin');
try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
} catch (e) {
    console.log('⚠️ Service account key not found, attempting keyless auth with default Project ID...');
    admin.initializeApp({
        projectId: 'tontetic-admin'
    });
}

const db = admin.firestore();

const plans = [
    // --- PARTIICULIERS (B2C) ---
    {
        id: 'plan_gratuit',
        code: 'USER_FREE',
        type: 'user',
        audience: 'user',
        name: 'Gratuit',
        description: 'Pour découvrir les tontines sans engagement.',
        emoji: '🆓',
        status: 'active',
        isActive: true,
        sortOrder: 1,
        billingPeriod: 'none',
        prices: { 'EUR': 0, 'XOF': 0 },
        stripePriceId: null,
        limits: {
            maxCircles: 1,
            maxMembers: 5,
            hasAlerts: false,
            hasPriorityAI: false
        },
        features: ['1 tontine active', 'Vote & Chat inclus', 'Wallet sécurisé'],
        supportLevel: 'Communauté'
    },
    {
        id: 'plan_starter',
        code: 'USER_STARTER',
        type: 'user',
        audience: 'user',
        name: 'Starter',
        description: 'Idéal pour vos premières tontines régulières.',
        emoji: '🚀',
        status: 'active',
        isActive: true,
        sortOrder: 2,
        billingPeriod: 'month',
        prices: { 'EUR': 3.99, 'XOF': 2500 },
        stripePriceId: 'price_1SnnDPCpguZvNb1UKvVOOhJH',
        limits: {
            maxCircles: 2,
            maxMembers: 10,
            hasAlerts: false,
            hasPriorityAI: false
        },
        features: ['2 tontines actives', 'Plafond 500€', 'Support Email'],
        isRecommended: true,
        supportLevel: 'Email (48h)'
    },
    {
        id: 'plan_standard',
        code: 'USER_STANDARD',
        type: 'user',
        audience: 'user',
        name: 'Standard',
        description: 'La tontine entre amis et famille en toute sérénité.',
        emoji: '⭐',
        status: 'active',
        isActive: true,
        sortOrder: 3,
        billingPeriod: 'month',
        prices: { 'EUR': 6.99, 'XOF': 4500 },
        stripePriceId: 'price_1SnnMNCpguZvNb1UxajfkrK2',
        limits: {
            maxCircles: 3,
            maxMembers: 15,
            hasAlerts: true,
            hasPriorityAI: false
        },
        features: ['3 tontines actives', 'Alertes de sécurité', 'Support Privilège'],
        supportLevel: 'Prioritaire (24h)'
    },
    {
        id: 'plan_premium',
        code: 'USER_PREMIUM',
        type: 'user',
        audience: 'user',
        name: 'Premium',
        description: 'Le summum de la gestion de tontine avec IA avancée.',
        emoji: '💎',
        status: 'active',
        isActive: true,
        sortOrder: 4,
        billingPeriod: 'month',
        prices: { 'EUR': 9.99, 'XOF': 6500 },
        stripePriceId: 'price_1SnnOmCpguZvNb1UXliBvti3',
        limits: {
            maxCircles: 5,
            maxMembers: 20,
            hasAlerts: true,
            hasPriorityAI: true
        },
        features: ['5 tontines actives', 'IA Tontii Prioritaire', 'Support Dédié'],
        supportLevel: 'Dédié (12h)'
    },

    // --- ENTREPRISES (B2B) ---
    {
        id: 'plan_corporate_starter',
        code: 'CORP_STARTER',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Starter Corp',
        description: 'Solution d\'épargne pour petites équipes.',
        emoji: '🏢',
        status: 'active',
        isActive: true,
        sortOrder: 10,
        billingPeriod: 'month',
        prices: { 'EUR': 19.99, 'XOF': 13110 },
        stripePriceId: null,
        limits: {
            maxEmployees: 12,
            maxCircles: 1,
            maxMembers: 12
        },
        features: ['12 salariés max', 'Dashboard B2B', 'Support Flexible'],
        supportLevel: 'B2B Standard'
    },
    {
        id: 'plan_corporate_starter_pro',
        code: 'CORP_STARTER_PRO',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Starter Pro Corp',
        description: 'Pour les entreprises en croissance.',
        emoji: '🏢+',
        status: 'active',
        isActive: true,
        sortOrder: 11,
        billingPeriod: 'month',
        prices: { 'EUR': 29.99, 'XOF': 19670 },
        stripePriceId: null,
        limits: {
            maxEmployees: 24,
            maxCircles: 2,
            maxMembers: 12
        },
        features: ['24 salariés max', '2 tontines simultanées', 'Support B2B'],
        supportLevel: 'B2B Standard'
    },
    {
        id: 'plan_corporate_team',
        code: 'CORP_TEAM',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Team Corp',
        description: 'Gestion centralisée pour vos collaborateurs.',
        emoji: '👥',
        status: 'active',
        isActive: true,
        sortOrder: 12,
        billingPeriod: 'month',
        prices: { 'EUR': 39.99, 'XOF': 26230 },
        stripePriceId: null,
        limits: {
            maxEmployees: 48,
            maxCircles: 4,
            maxMembers: 12
        },
        features: ['48 salariés max', 'Tontines multi-équipes', '4 tontines'],
        supportLevel: 'B2B Flexible'
    },
    {
        id: 'plan_corporate_team_pro',
        code: 'CORP_TEAM_PRO',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Team Pro Corp',
        description: 'Passez à l\'échelle supérieure.',
        emoji: '👥+',
        status: 'active',
        isActive: true,
        sortOrder: 13,
        billingPeriod: 'month',
        prices: { 'EUR': 49.99, 'XOF': 32790 },
        stripePriceId: null,
        limits: {
            maxEmployees: 60,
            maxCircles: 4,
            maxMembers: 15
        },
        features: ['60 salariés max', 'Multi-services', 'Support Prioritaire'],
        supportLevel: 'B2B Prioritaire'
    },
    {
        id: 'plan_corporate_dept',
        code: 'CORP_DEPT',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Department Corp',
        description: 'Idéal pour un département entier.',
        emoji: '🛡️',
        status: 'active',
        isActive: true,
        sortOrder: 14,
        billingPeriod: 'month',
        prices: { 'EUR': 69.99, 'XOF': 45900 },
        stripePriceId: null,
        limits: {
            maxEmployees: 84,
            maxCircles: 7,
            maxMembers: 15
        },
        features: ['84 salariés max', 'Scores par équipe', 'Reporting Avancé'],
        supportLevel: 'B2B Prioritaire'
    },
    {
        id: 'plan_corporate_enterprise',
        code: 'CORP_ENTERPRISE',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Enterprise Corp',
        description: 'Solution complète pour les grandes structures.',
        emoji: '🏛️',
        status: 'active',
        isActive: true,
        sortOrder: 15,
        billingPeriod: 'month',
        prices: { 'EUR': 89.99, 'XOF': 59000 },
        stripePriceId: null,
        limits: {
            maxEmployees: 108,
            maxCircles: 10,
            maxMembers: 20
        },
        features: ['108 salariés max', 'Export PDF/CSV', 'Audit complet'],
        supportLevel: 'B2B Dédié'
    },
    {
        id: 'plan_corporate_unlimited',
        code: 'CORP_UNLIMITED',
        type: 'enterprise',
        audience: 'enterprise',
        name: 'Unlimited Corp',
        description: 'Besoins sur mesure et volume illimité.',
        emoji: '♾️',
        status: 'active',
        isActive: true,
        sortOrder: 16,
        billingPeriod: 'month',
        prices: { 'EUR': 0, 'XOF': 0 },
        stripePriceId: null,
        limits: {
            maxEmployees: 999999,
            maxCircles: 999999,
            maxMembers: 30
        },
        features: ['Salariés illimités', 'Tontines illimitées', 'Support Premium'],
        supportLevel: 'B2B White Glove'
    },

    // --- MARCHANDS ---
    {
        id: 'plan_merchant_lite',
        code: 'MERCHANT_LITE',
        type: 'merchant',
        audience: 'merchant',
        name: 'Marchand Particulier',
        description: 'Pour vendre occasionnellement sur Tontetic.',
        emoji: '🛍️',
        status: 'active',
        isActive: true,
        sortOrder: 20,
        billingPeriod: 'month',
        prices: { 'EUR': 4.99, 'XOF': 3250 },
        stripePriceId: 'price_merchant_particulier_id',
        limits: {
            maxProducts: 5,
            boost_slots: 1
        },
        features: ['5 produits max', '1 créneau Boost', 'KYC Light'],
        supportLevel: 'Vendeur Standard'
    },
    {
        id: 'plan_merchant_pro',
        code: 'MERCHANT_PRO',
        type: 'merchant',
        audience: 'merchant',
        name: 'Marchand Vérifié',
        description: 'Solution pro pour les commerçants établis.',
        emoji: '🏪',
        status: 'active',
        isActive: true,
        sortOrder: 21,
        billingPeriod: 'month',
        prices: { 'EUR': 9.99, 'XOF': 6500 },
        stripePriceId: 'price_merchant_verifie_id',
        limits: {
            maxProducts: 999,
            boost_slots: 5
        },
        features: ['Produits illimités', '5 créneaux Boost', 'Badge Vérifié'],
        supportLevel: 'Vendeur Prioritaire'
    }
];

async function populate() {
    for (const plan of plans) {
        await db.collection('plans').doc(plan.id).set(plan);
        console.log(`✅ Plan ${plan.id} ajouté.`);
    }
    console.log('🚀 Population terminée !');
}

populate().catch(console.error);
