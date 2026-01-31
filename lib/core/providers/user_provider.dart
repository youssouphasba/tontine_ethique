import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tontetic/core/models/entitlement_model.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/services/security_service.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/services/auth_service.dart';

class UserNotifier extends StateNotifier<UserState> {
  final Ref ref;
  StreamSubscription? _userSub;
  StreamSubscription? _entitlementSub;

  // V17: Euro par défaut, FCFA si numéro africain détecté
  UserNotifier(this.ref) : super(UserState(
    uid: '',
    phoneNumber: '', 
    isPremium: false,
    activeCirclesCount: 0,
    zone: UserZone.zoneEuro,
    status: AccountStatus.guest,
    encryptedName: '',
    planId: null,
  )) {
    initSync();
  }

  /// V17: Synchronise l'état local avec les données de Firebase/Firestore
  void syncWithFirebase(String uid, Map<String, dynamic> data) {
    if (!mounted) return;

    final phone = data['phone'] ?? '';
    final zone = phone.isNotEmpty ? detectZoneFromPhone(phone) : UserZone.zoneEuro;
    
    AccountStatus accountStatus = AccountStatus.guest;
    if (data['status'] != null) {
      try {
        accountStatus = AccountStatus.values.firstWhere(
          (e) => e.toString().split('.').last == data['status'],
          orElse: () => data['isVerified'] == true ? AccountStatus.verified : AccountStatus.guest,
        );
      } catch (_) {
        accountStatus = data['isVerified'] == true ? AccountStatus.verified : AccountStatus.guest;
      }
    } else {
      accountStatus = data['isVerified'] == true ? AccountStatus.verified : AccountStatus.guest;
    }

    state = state.copyWith(
      uid: uid,
      phoneNumber: phone,
      zone: zone,
      encryptedName: SecurityService.encryptData(data['fullName'] ?? ''),
      email: data['email'] ?? '',
      isMerchant: data['isMerchant'] ?? false,
      isPremium: data['isPremium'] ?? (data['planId'] != null && data['planId'] != 'plan_gratuit'),
      status: accountStatus,
      honorScore: data['honorScore'] ?? 50,
      photoUrl: data['photoUrl'],
      stripeCustomerId: data['stripeCustomerId'],
      stripeSubscriptionId: data['stripeSubscriptionId'],
      stripeConnectAccountId: data['stripeConnectAccountId'],
      stripeConnectOnboardingComplete: data['stripeConnectOnboardingComplete'] ?? false,
      planId: data['planId'] ?? 'plan_gratuit',
      activeCirclesCount: data['activeCirclesCount'] ?? 0, // Load from Firestore for limit enforcement
    );
  }

  /// Updates the user's current plan ID
  Future<void> setPlanId(String planId) async {
    if (!mounted) return;
    state = state.copyWith(planId: planId);
    
    // Persist to Firebase
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(state.uid)
          .update({
            'planId': planId,
            // Also update legacy field if it matches a known tier
            'subscriptionTier': planId.split('_').last, 
          });
    }
  }

  /// Initialise la synchronisation temps réel avec Firestore
  void initSync() {
    // Watch Auth state to determine which user to sync
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((firebaseUser) {
        // Cancel previous subscriptions if any
        _userSub?.cancel();
        _entitlementSub?.cancel();

        if (firebaseUser != null) {
          debugPrint('[USER_SYNC] 🔄 Démarrage synchronisation pour ${firebaseUser.uid}');
          
          // V23: Set UID immediately to avoid empty states during sync
          if (mounted) {
            state = state.copyWith(uid: firebaseUser.uid);
          }
          
          _userSub = FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots()
              .listen((doc) {
                if (!mounted) return;
                if (doc.exists && doc.data() != null) {
                  debugPrint('[USER_SYNC] ✅ Données reçues pour ${firebaseUser.uid}');
                  syncWithFirebase(firebaseUser.uid, doc.data()!);
                }
              }, onError: (e) {
                debugPrint('[USER_SYNC] ❌ Erreur Firestore User: $e');
              });

          // Sync Entitlements [NEW]
          _entitlementSub = FirebaseFirestore.instance
              .collection('entitlements')
              .doc(firebaseUser.uid)
              .snapshots()
              .listen((doc) {
                if (doc.exists && doc.data() != null) {
                  debugPrint('[USER_SYNC] 🔑 Entitlements reçus pour ${firebaseUser.uid}');
                  final entitlement = Entitlement.fromFirestore(doc);
                  if (mounted) {
                    state = state.copyWith(entitlement: entitlement);
                  }
                }
              });
        } else {
          debugPrint('[USER_SYNC] 🛑 Arrêt synchronisation (déconnexion)');
          clearState();
        }
      });
    });
  }

  /// Réinitialise l'état (déconnexion)
  void clearState() {
    if (!mounted) return;
    state = UserState(
      uid: '',
      phoneNumber: '',
      isPremium: false,
      zone: UserZone.zoneEuro,
      status: AccountStatus.guest,
      encryptedName: '',
    );
  }

  static UserZone detectZoneFromPhone(String phone) {
    if (phone.startsWith('+33') || phone.startsWith('0')) {
      return UserZone.zoneEuro;
    } 
    // PHASE 1: FRANCE ONLY DEPLOYMENT
    // Temporary disable Senegal Zone (+221) detection to ensure 
    // all users (even testers) see only Euro/Stripe elements.
    /*
    else if (phone.startsWith('+221')) { // Senegal
      return UserZone.zoneFCFA;
    }
    */
    return UserZone.zoneEuro;
  }

  void setUser(String phone, bool premium) {
    final zone = detectZoneFromPhone(phone);
    if (!mounted) return;
    state = state.copyWith(phoneNumber: phone, isPremium: premium, zone: zone);
  }

  Future<void> updateProfile({
    required String name, 
    required String address,
    required UserType type,
    String? siret,
    String? representative,
    String? birthDate,
    UserZone? zone,
  }) async {
    // Store encrypted locally
    if (mounted) {
      state = state.copyWith(
        encryptedName: SecurityService.encryptData(name),
        encryptedAddress: SecurityService.encryptData(address),
        userType: type,
        encryptedSiret: siret != null ? SecurityService.encryptData(siret) : '',
        encryptedRepresentative: representative != null ? SecurityService.encryptData(representative) : '',
        encryptedBirthDate: birthDate != null ? SecurityService.encryptData(birthDate) : '',
        status: AccountStatus.pending,
        zone: zone ?? state.zone,
      );
    }

    // Persist to Firestore
    final uid = ref.read(authServiceProvider).currentUserUid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fullName': name,
          'userType': type.name,
          'status': AccountStatus.pending.name,
          'zone': (zone ?? state.zone).name,
        });
        debugPrint('[USER_PROVIDER] ✅ Profile persisted to Firestore for $uid');
      } catch (e) {
        debugPrint('[USER_PROVIDER] ❌ Error persisting profile: $e');
      }
    }
  }

  void incrementActiveCircles() {
    if (mounted) {
      state = state.copyWith(activeCirclesCount: state.activeCirclesCount + 1);
    }
  }
  
  void validateAccount() {
    if (mounted) {
      state = state.copyWith(status: AccountStatus.verified);
    }
  }

  void submitKYC() {
    if (mounted) {
      state = state.copyWith(status: AccountStatus.pending);
    }
  }

  void upgradeToPremium() {
    if (mounted) {
      state = state.copyWith(isPremium: true);
    }
  }

  void switchZone(UserZone newZone) {
    if (mounted) {
      state = state.copyWith(zone: newZone);
    }
  }

  void setSubscription(String planCode) {
    // Initialisation : CREATED / AWAITING_ACTIVATION
    // V17: We create a temporary Entitlement to reflect immediate UI change
    // Real truth comes from Firestore sync
    if (mounted) {
      state = state.copyWith(
        planId: planCode,
        entitlement: Entitlement(
          userId: state.uid,
          currentPlanCode: planCode,
          planSource: 'app_selection',
          status: 'awaiting_payment', // Temporary status
          updatedAt: DateTime.now(),
        )
      );
    }
  }

  void activateSubscriptionBilling() {
    // Triggered at start_tontine()
    // Optimistic update
    if (mounted && state.entitlement != null) {
      state = state.copyWith(
        entitlement: Entitlement(
          userId: state.uid,
          currentPlanCode: state.entitlement!.currentPlanCode,
          planSource: state.entitlement!.planSource,
          status: 'active', // Optimistic active
          updatedAt: DateTime.now(),
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
        )
      );
    }
  }

  void decrementActiveCircles() {
    if (mounted) {
      state = state.copyWith(activeCirclesCount: (state.activeCirclesCount - 1).clamp(0, 999));
    }
  }

  void updateActiveCircles(int count) {
    if (mounted) {
      state = state.copyWith(activeCirclesCount: count);
    }
  }


  String formatContent(double amount) {
    // Strict separation: Use the locale and symbol of the current zone
    final formatter = NumberFormat.currency(
      locale: state.zone.locale,
      symbol: state.zone.currency,
      decimalDigits: state.zone == UserZone.zoneFCFA ? 0 : 2, // No decimals for FCFA usually
    );
    return formatter.format(amount);
  }

  void updateStripeCustomerId(String customerId) {
    if (mounted) {
      state = state.copyWith(stripeCustomerId: customerId);
    }
  }

  void updateStripeSubscriptionId(String subscriptionId) {
    if (mounted) {
      state = state.copyWith(stripeSubscriptionId: subscriptionId);
    }
  }

  void updateStripeConnectAccountId(String? accountId) {
    if (mounted) {
      state = state.copyWith(stripeConnectAccountId: accountId);
    }
    
    // Persist to Firestore
    final uid = ref.read(authServiceProvider).currentUserUid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'stripeConnectAccountId': accountId,
      });
    }
  }

  void updateStripeConnectOnboardingComplete(bool complete) {
    if (mounted) {
      state = state.copyWith(stripeConnectOnboardingComplete: complete);
    }
    
    // Persist to Firestore
    final uid = ref.read(authServiceProvider).currentUserUid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'stripeConnectOnboardingComplete': complete,
      });
    }
  }

  // V3.5 + V5.1 Methods
  void updateExtendedProfile({String? bio, String? job, String? company, BioPrivacyLevel? privacy}) {
    if (mounted) {
      state = state.copyWith(
        bio: bio,
        jobTitle: job,
        company: company,
        bioPrivacy: privacy
      );
    }
  }

  void updatePhoto(String url) {
    if (mounted) {
      state = state.copyWith(photoUrl: url);
    }
  }

  void requestCertification() {
    // Simule une certification instantanée pour la démo
    if (mounted) {
      state = state.copyWith(
        isProfileCertified: true,
        trustScoreHistory: [...state.trustScoreHistory, '+20 (Profil Certifié ✅)']
      );
    }
  }

  void switchTheme(bool isDark) {
    if (mounted) {
      state = state.copyWith(themeMode: isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  Future<bool> deleteAccount(AuthService authService) async {
    // 1. REAL-TIME SECURITY CHECK: Query Firestore for active circles
    try {
      final uid = state.uid;
      if (uid == null || uid.isEmpty) {
        debugPrint('[DELETION] Blocked: No UID found');
        return false;
      }
      
      final activeCirclesQuery = await FirebaseFirestore.instance
          .collection('circles')
          .where('members', arrayContains: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (activeCirclesQuery.docs.isNotEmpty) {
        debugPrint('[DELETION] Blocked: User has ${activeCirclesQuery.docs.length} active circle(s)');
        return false; // Deletion blocked
      }
      
      debugPrint('[DELETION] Check passed: No active circles found for $uid');
    } catch (e) {
      debugPrint('[DELETION] Error checking circles: $e - allowing deletion');
      // If we can't verify, proceed cautiously (allow deletion)
    }
    
    // 2. Real Logic via AuthService
    final result = await authService.deleteAccount();
    
    if (result.success) {
      debugPrint('[DELETION] Success for UID: ${state.uid}');
      // 3. Reset State (Logout)
      clearState();
      return true;
    } else {
      debugPrint('[DELETION] Failed: ${result.error}');
      return false;
    }
  }

  
  // V11.2: Sign Merchant Charter
  void signMerchantCharter() {
    if (mounted) {
      state = state.copyWith(hasSignedCharter: true);
    }
  }

  // RGPD Art.17: Anonymize user data
  void anonymize(String anonymousId) {
    if (mounted) {
      state = UserState(
        uid: anonymousId,
        phoneNumber: anonymousId,
        isPremium: false,
        zone: state.zone,
        status: AccountStatus.guest,
        encryptedName: SecurityService.encryptData('[SUPPRIMÉ]'),
        email: '[supprime@anonyme.rgpd]',
        honorScore: 0,
      );
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _entitlementSub?.cancel();
    super.dispose();
  }
}

final userProvider = StateNotifierProvider.autoDispose<UserNotifier, UserState>((ref) {
  return UserNotifier(ref);
});
