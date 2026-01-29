import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tontetic/core/services/security_service.dart';

/// Résultat d'une opération d'authentification
class AuthResult {
  final bool success;
  final String? error;
  final String? message;
  final dynamic data;
  final bool isNewUser;

  AuthResult({required this.success, this.error, this.message, this.data, this.isNewUser = false});
}

// Service d'authentification centralisé
// Gère l'inscription, la connexion et la session utilisateure
class AuthService {
  // Use late for lazy initialization to prevent crashes if Firebase isn't ready
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? _verificationId;

  /// Stream de l'état de l'utilisateur
  Stream<User?> get userStream => _auth.authStateChanges();
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Connexion avec Email/Mot de passe
  Future<AuthResult> signInWithEmail({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult(success: false, error: 'Une erreur inattendue est survenue');
    }
  }

  /// Inscription avec Email/Mot de passe
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String role = 'Membre',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _createUserProfile(
          uid: credential.user!.uid,
          email: email,
          fullName: fullName,
          role: role,
        );
      }

      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Envoie un OTP pour vérification (sans connexion persistante)
  Future<AuthResult> sendOtp(String phoneNumber) async {
    try {
      final comp = Completer<AuthResult>();
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (Android usually)
          // We don't sign in automatically here for registration flow
        },
        verificationFailed: (FirebaseAuthException e) {
          comp.complete(AuthResult(success: false, error: _mapFirebaseError(e.code)));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          comp.complete(AuthResult(success: true, message: 'Code envoyé au $phoneNumber'));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return await comp.future;
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Valide l'OTP sans créer de profil complet (juste vérification)
  Future<AuthResult> validateOtp(String smsCode) async {
    try {
       if (_verificationId == null) {
        return AuthResult(success: false, error: 'Session expirée');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Verify by attempting sign-in (creates a temporary anonymous-like session or real phone session)
      final userCredential = await _auth.signInWithCredential(credential);
      
      // If successful, we sign out immediately to allow email registration
      await _auth.signOut();
      
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Initialise la connexion par téléphone (Envoi du SMS)
  Future<AuthResult> signInWithPhone(String phoneNumber) async {
    try {
      final comp = Completer<AuthResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          comp.complete(AuthResult(success: false, error: _mapFirebaseError(e.code)));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          comp.complete(AuthResult(success: true, message: 'Code envoyé au $phoneNumber'));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return await comp.future;
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Vérifie le code OTP reçu par SMS
  Future<AuthResult> verifyOtp({required String phone, required String token}) async {
    try {
      if (_verificationId == null) {
        return AuthResult(success: false, error: 'Session de vérification expirée');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: token,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Créer profil si nouveau
      if (userCredential.user != null && userCredential.additionalUserInfo!.isNewUser) {
         await _createUserProfile(
          uid: userCredential.user!.uid,
          email: '',
          fullName: 'Utilisateur $phone',
          role: 'Membre',
          phone: phone,
        );
      }

      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Connexion avec Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      debugPrint('DEBUG_AUTH: Starting Google Sign-In');
      UserCredential userCredential;

      if (kIsWeb) {
        // WEB: Use Firebase SDK directly (avoid google_sign_in package issues)
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        
        try {
          userCredential = await _auth.signInWithPopup(provider);
        } catch (e) {
          // Fallback to redirect if popup fails (e.g., popup blocker)
          debugPrint('DEBUG_AUTH: Popup failed, trying redirect: $e');
          // Note: signInWithRedirect is tricky in Flutter SPA, stick to popup or show error
          return AuthResult(success: false, error: 'La connexion a échoué. Vérifiez vos bloqueurs de popups.');
        }
      } else {
        // MOBILE: Use native Google Sign-In flow
        // Step 1: Sign in with Google
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('DEBUG_AUTH: Google Sign-In cancelled by user');
          return AuthResult(success: false, error: 'Connexion annulée');
        }

        debugPrint('DEBUG_AUTH: Google user obtained: ${googleUser.email}');
        
        // Step 2: Get authentication tokens with timeout
        debugPrint('DEBUG_AUTH: Getting authentication tokens...');
        final GoogleSignInAuthentication googleAuth;
        try {
          googleAuth = await googleUser.authentication.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout lors de la récupération des tokens Google');
            },
          );
        } catch (e) {
          debugPrint('DEBUG_AUTH: Error getting tokens: $e');
          return AuthResult(success: false, error: 'Erreur tokens Google: $e');
        }
        
        // Step 3: Create Firebase credential
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Step 4: Sign in with Firebase
        userCredential = await _auth.signInWithCredential(credential);
      }
      
      debugPrint('DEBUG_AUTH: Firebase auth successful! User: ${userCredential.user?.email}');

      bool isNewUser = false;
      if (userCredential.user != null) {
        // Check if user already exists in Firestore
        final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
        // A user is "new" or "incomplete" if they don't have a phone number yet
        isNewUser = !userDoc.exists || (userDoc.data()?['phone'] == null);
        
        debugPrint('DEBUG_AUTH: Is new user: $isNewUser');
        
        await _createUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          fullName: userCredential.user!.displayName ?? 'Utilisateur Google',
          role: 'Membre',
          photoUrl: userCredential.user!.photoURL,
        );
      }

      debugPrint('DEBUG_AUTH: Google Sign-In complete!');
      return AuthResult(success: true, isNewUser: isNewUser);
    } catch (e, stackTrace) {
      debugPrint('DEBUG_AUTH: Error in signInWithGoogle: $e');
      debugPrint('DEBUG_AUTH: Stack trace: $stackTrace');
      return AuthResult(success: false, error: 'Erreur: $e');
    }
  }

  /// Réinitialisation du mot de passe
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    }
  }

  /// Envoyer email de vérification
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return AuthResult(success: true);
      }
      return AuthResult(success: false, error: 'Utilisateur non connecté ou déjà vérifié');
    } catch (e) {
       return AuthResult(success: false, error: e.toString());
    }
  }

  /// Changer le mot de passe (utilisateur connecté)
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(success: false, error: 'Utilisateur non connecté');
      }
      if (user.email == null) {
        return AuthResult(success: false, error: 'Compte sans email (Google/téléphone)');
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      
      debugPrint('DEBUG_AUTH: Password changed successfully');
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      debugPrint('DEBUG_AUTH: Password change error: ${e.code}');
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('DEBUG_AUTH: Password change exception: $e');
      return AuthResult(success: false, error: 'Erreur: $e');
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Suppression définitive du compte (RGPD)
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult(success: false, error: "Utilisateur non trouvé");

      final uid = user.uid;

      // 1. Supprimer les données Firestore
      await _db.collection('users').doc(uid).delete();

      // 2. Supprimer de Firebase Auth
      await user.delete();

      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AuthResult(success: false, error: "Sécurité : Veuillez vous reconnecter avant de supprimer votre compte.");
      }
      return AuthResult(success: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Traduction des erreurs Firebase
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found': return 'Aucun utilisateur trouvé pour cet email.';
      case 'wrong-password': return 'Mot de passe incorrect.';
      case 'invalid-credential': return 'Email ou mot de passe incorrect.'; // New Firebase error code
      case 'email-already-in-use': return 'Cet email est déjà utilisé.';
      case 'invalid-email': return 'Email non valide.';
      case 'weak-password': return 'Le mot de passe est trop faible.';
      case 'operation-not-allowed': return 'Opération non autorisée.';
      case 'invalid-verification-code': return 'Code de vérification invalide.';
      case 'invalid-verification-id': return 'ID de vérification invalide.';
      case 'too-many-requests': return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed': return 'Erreur réseau. Vérifiez votre connexion.';
      case 'user-disabled': return 'Ce compte a été désactivé.';
      default: return 'Une erreur de sécurité est survenue ($code).';
    }
  }

  /// Crée ou met à jour le profil utilisateur dans Firestore
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String fullName,
    required String role,
    String? phone,
    String? photoUrl,
  }) async {
    final userDoc = _db.collection('users').doc(uid);
    final snapshot = await userDoc.get();
    
    if (!snapshot.exists) {
      await userDoc.set({
        'uid': uid,
        'email': email,
        'phone': phone,
        'fullName': fullName,
        'role': role,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 0,
        'trustScore': 5,
        'honorScore': 50,
        'isVerified': false,
        'isMerchant': false,
        'publicKey': SecurityService.generateKeys()['publicKey'], // V11.32 Production RSA
      });
    }
  }

  /// Met à jour les données Stripe de l'utilisateur dans Firestore
  Future<void> updateUserStripeData({
    required String uid,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
  }) async {
    final Map<String, dynamic> data = {};
    if (stripeCustomerId != null) data['stripeCustomerId'] = stripeCustomerId;
    if (stripeSubscriptionId != null) data['stripeSubscriptionId'] = stripeSubscriptionId;
    
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  /// Récupère les données Firestore de l'utilisateur
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    return snapshot.data();
  }
}
