const admin = require('firebase-admin');

// Service account initialization
try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Initialisé avec la clé du compte de service.');
} catch (e) {
    console.log('⚠️ serviceAccountKey.json non trouvé, utilisation de l\'initialisation par défaut...');
    admin.initializeApp({
        projectId: 'tontetic-admin'
    });
}

const uid = 'qxXTqA7sbFbOlvCQxhpw1GSQ8K32';

async function setAdminClaim(userUid) {
    try {
        await admin.auth().setCustomUserClaims(userUid, { admin: true });
        console.log(`✅ Custom claims "admin: true" définis avec succès pour l'UID: ${userUid}`);

        // Vérification
        const user = await admin.auth().getUser(userUid);
        console.log('🔍 Claims actuels:', user.customClaims);

        process.exit(0);
    } catch (error) {
        console.error('❌ Erreur lors de la définition des claims:', error);
        process.exit(1);
    }
}

setAdminClaim(uid);
