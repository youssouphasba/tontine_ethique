# 🚀 Guide de Déploiement - Back-Office Admin Tontetic

## 📋 Table des matières
1. [Prérequis](#prérequis)
2. [Option 1 : Firebase Hosting](#option-1--firebase-hosting-recommandé)
3. [Option 2 : Vercel](#option-2--vercel-gratuit)
4. [Option 3 : Serveur VPS](#option-3--serveur-vps)
5. [Sécurité en Production](#sécurité-en-production)
6. [Configuration DNS](#configuration-dns)
7. [Connexion à la Base de Données](#connexion-à-la-base-de-données)

---

## Prérequis

### Outils nécessaires
```bash
# Node.js (v18+)
node --version

# npm
npm --version

# Firebase CLI (si Firebase)
npm install -g firebase-tools
```

### Fichiers du projet
```
admin_backoffice/
├── index.html          # Application principale
├── DEPLOYMENT.md       # Ce guide
└── firebase.json       # Config Firebase (à créer)
```

---

## Option 1 : Firebase Hosting (Recommandé)

### Étape 1 : Créer un projet Firebase
1. Aller sur [console.firebase.google.com](https://console.firebase.google.com)
2. Cliquer "Ajouter un projet"
3. Nom : `tontetic-admin`
4. Désactiver Google Analytics (optionnel)

### Étape 2 : Initialiser Firebase
```bash
cd admin_backoffice

# Connexion
firebase login

# Initialisation
firebase init hosting
```

Réponses :
- What do you want to use as your public directory? → `.`
- Configure as a single-page app? → `Yes`
- Set up automatic builds with GitHub? → `No`

### Étape 3 : Déployer
```bash
firebase deploy --only hosting
```

### Résultat
```
✔ Deploy complete!
Hosting URL: https://tontetic-admin.web.app
```

### Étape 4 : Domaine personnalisé (optionnel)
1. Firebase Console → Hosting → Domaines personnalisés
2. Ajouter `admin.tontetic.com`
3. Suivre les instructions DNS

---

## Option 2 : Vercel (Gratuit)

### Étape 1 : Installation
```bash
npm install -g vercel
```

### Étape 2 : Déploiement
```bash
cd admin_backoffice
vercel
```

### Étape 3 : Production
```bash
vercel --prod
```

### Résultat
```
Production: https://tontetic-admin.vercel.app
```

---

## Option 3 : Serveur VPS

### Configuration Nginx
```nginx
server {
    listen 443 ssl http2;
    server_name admin.tontetic.com;

    ssl_certificate /etc/letsencrypt/live/admin.tontetic.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.tontetic.com/privkey.pem;

    root /var/www/admin_backoffice;
    index index.html;

    # Sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com;" always;

    # IP Whitelist (recommandé)
    # allow 192.168.1.0/24;
    # deny all;

    location / {
        try_files $uri $uri/ /index.html;
    }
}

# Redirection HTTP → HTTPS
server {
    listen 80;
    server_name admin.tontetic.com;
    return 301 https://$server_name$request_uri;
}
```

### Certificat SSL (Let's Encrypt)
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d admin.tontetic.com
```

---

## Sécurité en Production

### 1. Authentification Firebase Auth

Modifier `index.html` pour intégrer Firebase Auth :

```javascript
// Configuration Firebase
const firebaseConfig = {
    apiKey: "VOTRE_API_KEY",
    authDomain: "tontetic-admin.firebaseapp.com",
    projectId: "tontetic-admin"
};

firebase.initializeApp(firebaseConfig);

// Vérification de l'authentification
firebase.auth().onAuthStateChanged((user) => {
    if (user && user.email.endsWith('@tontetic.com')) {
        // Utilisateur autorisé
        showDashboard();
    } else {
        // Non autorisé
        showLogin();
    }
});

// Connexion
function login(email, password) {
    firebase.auth().signInWithEmailAndPassword(email, password)
        .then((userCredential) => {
            console.log('[AUDIT] Login:', email, new Date().toISOString());
        })
        .catch((error) => {
            alert('Erreur: ' + error.message);
        });
}
```

### 2. Liste blanche des emails admin

```javascript
const AUTHORIZED_ADMINS = [
    'admin@tontetic.com',
    'moderator@tontetic.com',
    'support@tontetic.com'
];

function isAuthorized(email) {
    return AUTHORIZED_ADMINS.includes(email) || 
           email.endsWith('@tontetic.com');
}
```

### 3. Variables d'environnement

Créer `.env` (NE PAS COMMIT) :
```env
FIREBASE_API_KEY=xxx
DATABASE_URL=xxx
ADMIN_EMAILS=admin@tontetic.com,mod@tontetic.com
```

### 4. Headers de sécurité

Ajouter dans `firebase.json` :
```json
{
  "hosting": {
    "public": ".",
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "X-Frame-Options", "value": "SAMEORIGIN" },
          { "key": "X-Content-Type-Options", "value": "nosniff" },
          { "key": "X-XSS-Protection", "value": "1; mode=block" },
          { "key": "Strict-Transport-Security", "value": "max-age=31536000" }
        ]
      }
    ]
  }
}
```

---

## Configuration DNS

### Sous-domaine admin.tontetic.com

| Type | Nom | Valeur | TTL |
|------|-----|--------|-----|
| CNAME | admin | tontetic-admin.web.app | 3600 |

Ou pour VPS :
| Type | Nom | Valeur | TTL |
|------|-----|--------|-----|
| A | admin | 123.45.67.89 | 3600 |

---

## Connexion à la Base de Données

### Architecture
```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  App Mobile  │────▶│   Firebase   │◀────│ Admin Web    │
│   Flutter    │     │   Firestore  │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Règles Firestore sécurisées

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Fonction admin
    function isAdmin() {
      return request.auth != null && 
             request.auth.token.email.matches('.*@tontetic[.]com');
    }
    
    // Utilisateurs - lecture admin only
    match /users/{userId} {
      allow read: if isAdmin();
      allow write: if isAdmin() && 
                   !('balance' in request.resource.data); // Pas de modif fonds
    }
    
    // Cercles
    match /circles/{circleId} {
      allow read: if isAdmin();
      allow update: if isAdmin() && 
                    !('totalAmount' in request.resource.data); // Pas de modif montants
    }
    
    // Produits marchands
    match /products/{productId} {
      allow read, write: if isAdmin();
    }
    
    // Logs audit (immutables)
    match /audit_logs/{logId} {
      allow read: if isAdmin();
      allow create: if isAdmin();
      allow update, delete: if false; // JAMAIS modifiable
    }
  }
}
```

---

## Checklist Pré-Production

- [ ] HTTPS activé avec certificat valide
- [ ] Authentification Firebase Auth configurée
- [ ] Liste des admins autorisés définie
- [ ] Headers de sécurité configurés
- [ ] Règles Firestore déployées
- [ ] DNS configuré pour admin.tontetic.com
- [ ] Test de connexion depuis l'app mobile
- [ ] Logs d'audit fonctionnels
- [ ] Backup automatique configuré

---

## Support

Pour toute question :
- Email : tech@tontetic.com
- Documentation : docs.tontetic.com

---

*Document généré le 05/01/2026*
