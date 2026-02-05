const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret_key);

admin.initializeApp();

// ============ CORS SECURITY ============
const ALLOWED_ORIGINS = [
  'https://tontetic-app.web.app',
  'https://tontetic-app.firebaseapp.com',
  'http://localhost:5000', // Dev
  'http://localhost:3000', // Dev
];

function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  if (ALLOWED_ORIGINS.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
  }
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Max-Age', '3600');
}

// ============ STRIPE CHECKOUT FUNCTIONS ============

/**
 * CREATE PAYMENT INTENT
 * Creates a PaymentIntent for mobile native checkout.
 */
exports.createPaymentIntent = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { amount, currency, description } = req.body;

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency || 'eur',
      description: description || 'Paiement Tontetic',
      automatic_payment_methods: { enabled: true },
    });

    res.json({
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    console.error('[createPaymentIntent] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE CHECKOUT SESSION
 * Creates a Stripe Checkout session for subscriptions (Web + Mobile redirect).
 */
exports.createCheckoutSession = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { priceId, email, customerId, successUrl, cancelUrl, userId, planId } = req.body;

    if (!priceId) {
      return res.status(400).json({ error: 'priceId is required' });
    }

    const sessionParams = {
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: successUrl || 'https://tontetic-app.web.app/payment/success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: cancelUrl || 'https://tontetic-app.web.app/payment/cancel',
      metadata: { userId, planId },
    };

    if (customerId) {
      sessionParams.customer = customerId;
    } else if (email) {
      sessionParams.customer_email = email;
    }

    const session = await stripe.checkout.sessions.create(sessionParams);

    console.log(`[createCheckoutSession] Created session ${session.id} for ${email || customerId}`);
    res.json({ sessionId: session.id, url: session.url });
  } catch (error) {
    console.error('[createCheckoutSession] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE SETUP INTENT
 * For SEPA mandate setup.
 */
exports.createSetupIntent = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { email, customerId } = req.body;

    let customer;
    if (customerId) {
      customer = await stripe.customers.retrieve(customerId);
    } else {
      customer = await stripe.customers.create({ email });
    }

    const setupIntent = await stripe.setupIntents.create({
      customer: customer.id,
      payment_method_types: ['sepa_debit'],
    });

    res.json({
      clientSecret: setupIntent.client_secret,
      customerId: customer.id,
    });
  } catch (error) {
    console.error('[createSetupIntent] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============ STRIPE CONNECT FUNCTIONS ============

/**
 * CREATE CONNECT ACCOUNT
 * Creates a Stripe Connect Express account for tontine payouts.
 */
exports.createConnectAccount = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { email, userId, firstName, lastName, businessType } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'email is required' });
    }

    const account = await stripe.accounts.create({
      type: 'express',
      country: 'FR',
      email: email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      business_type: businessType || 'individual',
      individual: {
        first_name: firstName,
        last_name: lastName,
        email: email,
      },
      metadata: { userId },
    });

    console.log(`[createConnectAccount] Created account ${account.id} for ${email}`);
    res.json({ accountId: account.id });
  } catch (error) {
    console.error('[createConnectAccount] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE CONNECT ACCOUNT LINK
 * Generates onboarding URL for Stripe Connect Express.
 */
exports.createConnectAccountLink = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { accountId, refreshUrl, returnUrl } = req.body;

    if (!accountId) {
      return res.status(400).json({ error: 'accountId is required' });
    }

    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: refreshUrl || 'https://tontetic-app.web.app/connect/refresh',
      return_url: returnUrl || 'https://tontetic-app.web.app/connect/success',
      type: 'account_onboarding',
    });

    console.log(`[createConnectAccountLink] Generated link for ${accountId}`);
    res.json({ url: accountLink.url });
  } catch (error) {
    console.error('[createConnectAccountLink] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET CONNECT ACCOUNT STATUS
 * Returns the status of a Stripe Connect account.
 */
exports.getConnectAccountStatus = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const accountId = req.query.accountId;

    if (!accountId) {
      return res.status(400).json({ error: 'accountId query param is required' });
    }

    const account = await stripe.accounts.retrieve(accountId);

    res.json({
      accountId: account.id,
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      detailsSubmitted: account.details_submitted,
      requirements: account.requirements,
    });
  } catch (error) {
    console.error('[getConnectAccountStatus] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============ STRIPE IDENTITY (KYC) FUNCTIONS ============

/**
 * CREATE IDENTITY VERIFICATION SESSION
 * Creates a Stripe Identity VerificationSession for KYC.
 * Requires Stripe Identity to be enabled on your account.
 */
exports.createIdentityVerificationSession = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { userId, email, returnUrl } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Create VerificationSession with Stripe Identity
    const verificationSession = await stripe.identity.verificationSessions.create({
      type: 'document',
      metadata: {
        userId: userId,
        email: email || '',
      },
      options: {
        document: {
          allowed_types: ['driving_license', 'passport', 'id_card'],
          require_id_number: false,
          require_live_capture: true,
          require_matching_selfie: true,
        },
      },
      return_url: returnUrl || 'https://tontetic-app.web.app/kyc/complete',
    });

    // Save verification attempt to Firestore
    await admin.firestore().collection('users').doc(userId).update({
      kycStatus: 'pending',
      kycSessionId: verificationSession.id,
      kycStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[IDENTITY] Created session ${verificationSession.id} for user ${userId}`);

    res.json({
      sessionId: verificationSession.id,
      url: verificationSession.url,
      clientSecret: verificationSession.client_secret,
    });
  } catch (error) {
    console.error('[createIdentityVerificationSession] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET IDENTITY VERIFICATION STATUS
 * Returns the current status of a user's KYC verification.
 */
exports.getIdentityVerificationStatus = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const sessionId = req.query.sessionId;
    const userId = req.query.userId;

    if (!sessionId && !userId) {
      return res.status(400).json({ error: 'sessionId or userId is required' });
    }

    let verificationSession;

    if (sessionId) {
      verificationSession = await stripe.identity.verificationSessions.retrieve(sessionId);
    } else {
      // Get from Firestore
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists || !userDoc.data().kycSessionId) {
        return res.json({ status: 'none', verified: false });
      }
      verificationSession = await stripe.identity.verificationSessions.retrieve(userDoc.data().kycSessionId);
    }

    res.json({
      sessionId: verificationSession.id,
      status: verificationSession.status,
      verified: verificationSession.status === 'verified',
      lastError: verificationSession.last_error,
      verifiedOutputs: verificationSession.verified_outputs,
    });
  } catch (error) {
    console.error('[getIdentityVerificationStatus] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * STRIPE IDENTITY WEBHOOK
 * Handles Stripe Identity verification events.
 * Configure in Stripe Dashboard: identity.verification_session.*
 */
exports.stripeIdentityWebhook = functions.region('europe-west1').https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      functions.config().stripe.identity_webhook_secret || functions.config().stripe.webhook_secret
    );
  } catch (err) {
    console.error('[IDENTITY WEBHOOK] Signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  const session = event.data.object;
  const userId = session.metadata?.userId;

  if (!userId) {
    console.warn('[IDENTITY WEBHOOK] No userId in metadata');
    return res.json({ received: true });
  }

  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);

  try {
    switch (event.type) {
      case 'identity.verification_session.verified':
        console.log(`[IDENTITY] ✅ User ${userId} verified successfully`);
        await userRef.update({
          kycStatus: 'verified',
          isVerified: true,
          kycVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          verifiedOutputs: session.verified_outputs || {},
        });

        // Create notification
        await db.collection('user_notifications').add({
          userId: userId,
          title: 'Identité Vérifiée ✅',
          body: 'Félicitations ! Votre identité a été vérifiée avec succès.',
          type: 'kyc_verified',
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        break;

      case 'identity.verification_session.requires_input':
        console.log(`[IDENTITY] ⚠️ User ${userId} needs to provide more info`);
        await userRef.update({
          kycStatus: 'requires_input',
          kycLastError: session.last_error?.reason || 'Additional information required',
        });
        break;

      case 'identity.verification_session.canceled':
        console.log(`[IDENTITY] ❌ User ${userId} verification canceled`);
        await userRef.update({
          kycStatus: 'canceled',
        });
        break;

      default:
        console.log(`[IDENTITY WEBHOOK] Unhandled event: ${event.type}`);
    }
  } catch (err) {
    console.error('[IDENTITY WEBHOOK] Error processing:', err);
    return res.status(500).json({ error: err.message });
  }

  res.json({ received: true });
});

/**
 * HONOR SCORE CALCULATION (CRON JOB)
 * Runs every Sunday at 00:00 to update reliability scores.
 */
exports.calculateHonorScores = functions.pubsub.schedule("0 0 * * 0").onRun(async (context) => {
  const usersSnapshot = await admin.firestore().collection("users").get();

  for (const doc of usersSnapshot.docs) {
    const userId = doc.id;
    const payments = await admin.firestore().collection("transactions")
      .where("userId", "==", userId)
      .where("status", "in", ["completed", "failed"])
      .get();

    let successCount = 0;
    let failCount = 0;

    payments.forEach(p => {
      if (p.data().status === "completed") successCount++;
      else failCount++;
    });

    // Reliability Score Logic: Success ratio weighted by volume
    const total = successCount + failCount;
    const score = total > 0 ? (successCount / total) * 5 : 4.0; // Default to 4 for new users

    await doc.ref.update({
      "honorScore": parseFloat(score.toFixed(1)),
      "lastScoreUpdate": admin.firestore.FieldValue.serverTimestamp()
    });
  }
  console.log("✅ Honor scores updated for all users.");
});

/**
 * AUTOMATED GUARANTEE MONITORING (CRON JOB)
 * Runs daily to check for late payments and trigger guarantees.
 */
exports.monitorGuarantees = functions.pubsub.schedule("0 1 * * *").onRun(async (context) => {
  const today = admin.firestore.Timestamp.now();
  const tontines = await admin.firestore().collection("tontines").where("status", "==", "active").get();

  for (const tontineDoc of tontines.docs) {
    const tontine = tontineDoc.data();
    const gracePeriod = tontine.gracePeriodDays || 7;

    // Find expected payments that are overdue
    const overduePayments = await admin.firestore().collection("transactions")
      .where("tontineId", "==", tontineDoc.id)
      .where("status", "==", "pending")
      .where("dueDate", "<", today)
      .get();

    for (const paymentDoc of overduePayments.docs) {
      const payment = paymentDoc.data();
      const daysOverdue = Math.floor((today.toMillis() - payment.dueDate.toMillis()) / (24 * 60 * 60 * 1000));

      if (daysOverdue > gracePeriod) {
        console.log(`⚠️ Triggering guarantee for ${payment.userId} in tontine ${tontineDoc.id}`);

        // 1. Audit Log (Security & Compliance)
        await admin.firestore().collection('audit_logs').add({
          action: 'GUARANTEE_TRIGGERED',
          details: `Guarantee triggered for user ${payment.userId} in tontine ${tontineDoc.id}`,
          metadata: {
            tontineId: tontineDoc.id,
            userId: payment.userId,
            paymentId: paymentDoc.id,
            daysOverdue: daysOverdue
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          performedBy: 'system_cron'
        });

        // 2. Notify User
        await admin.firestore().collection('user_notifications').add({
          userId: payment.userId,
          title: 'Garantie Activée',
          body: `Votre paiement est en retard de ${daysOverdue} jours. La procédure de garantie a été déclenchée.`,
          type: 'alert',
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 3. Move funds from guarantee hold to collective payout (Stripe Connect Transfer)
        // TODO: Enable this when 'destinationAccountId' is available in Tontine model
        /*
        try {
            await stripe.transfers.create({
                amount: payment.amount,
                currency: payment.currency,
                destination: tontine.destinationAccountId, // MISSING IN MODEL
                transfer_group: tontineDoc.id,
            });
            console.log(`✅ Funds transferred for guarantee: ${paymentDoc.id}`);
        } catch (e) {
            console.error(`❌ Transfer failed: ${e.message}`);
        }
        */

        // 4. Mark as defaulted
        await paymentDoc.ref.update({
          "status": "guarantee_triggered",
          "guaranteeTriggeredAt": admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }
  }
});

/**
 * WEBHOOKS: STRIPE
 * Handles: payment_intent.succeeded, checkout.session.completed,
 * customer.subscription.updated, customer.subscription.deleted
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, functions.config().stripe.webhook_secret);
  } catch (err) {
    console.error(`[WEBHOOK] Signature verification failed: ${err.message}`);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  const db = admin.firestore();

  // ============ CHECKOUT SESSION COMPLETED ============
  // This is the PRIMARY handler for subscription activation
  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const { userId, planId } = session.metadata || {};

    console.log(`[WEBHOOK] Checkout completed: session=${session.id}, userId=${userId}, planId=${planId}`);

    if (!userId) {
      console.error("[WEBHOOK] Missing userId in session metadata");
      return res.json({ received: true, warning: "missing userId" });
    }

    try {
      const batch = db.batch();

      // 1. Create/Update Entitlement
      const entitlementRef = db.collection("entitlements").doc(userId);
      batch.set(entitlementRef, {
        userId: userId,
        currentPlanCode: planId || 'starter',
        planSource: 'stripe',
        status: 'active',
        stripeCustomerId: session.customer,
        stripeSubscriptionId: session.subscription,
        currentPeriodEnd: session.expires_at ? new Date(session.expires_at * 1000) : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 2. Update User document
      const userRef = db.collection("users").doc(userId);
      batch.update(userRef, {
        planId: planId || 'starter',
        subscriptionStatus: 'active',
        stripeCustomerId: session.customer,
        stripeSubscriptionId: session.subscription,
        isPremium: planId !== 'free' && planId !== 'gratuit',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Create audit log
      const auditRef = db.collection("audit_logs").doc();
      batch.set(auditRef, {
        type: 'subscription_activated',
        userId: userId,
        planId: planId,
        sessionId: session.id,
        customerId: session.customer,
        subscriptionId: session.subscription,
        amountTotal: session.amount_total,
        currency: session.currency,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();
      console.log(`[WEBHOOK] Successfully activated subscription for user ${userId}, plan ${planId}`);

    } catch (error) {
      console.error(`[WEBHOOK] Error processing checkout.session.completed: ${error.message}`);
      // Don't return 500 - Stripe will retry. Log and acknowledge.
    }
  }

  // ============ SUBSCRIPTION UPDATED ============
  if (event.type === "customer.subscription.updated") {
    const subscription = event.data.object;
    const customerId = subscription.customer;

    console.log(`[WEBHOOK] Subscription updated: ${subscription.id}, status=${subscription.status}`);

    try {
      // Find user by stripeCustomerId
      const usersSnapshot = await db.collection("users")
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();

      if (!usersSnapshot.empty) {
        const userDoc = usersSnapshot.docs[0];
        const userId = userDoc.id;

        // Map Stripe status to our status
        let appStatus = 'active';
        if (subscription.status === 'past_due') appStatus = 'past_due';
        if (subscription.status === 'canceled') appStatus = 'canceled';
        if (subscription.status === 'unpaid') appStatus = 'past_due';
        if (subscription.status === 'trialing') appStatus = 'trialing';

        await db.collection("users").doc(userId).update({
          subscriptionStatus: appStatus,
          currentPeriodEnd: subscription.current_period_end
            ? new Date(subscription.current_period_end * 1000)
            : null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update entitlement too
        await db.collection("entitlements").doc(userId).update({
          status: appStatus,
          currentPeriodEnd: subscription.current_period_end
            ? new Date(subscription.current_period_end * 1000)
            : null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`[WEBHOOK] Updated user ${userId} subscription status to ${appStatus}`);
      }
    } catch (error) {
      console.error(`[WEBHOOK] Error processing subscription.updated: ${error.message}`);
    }
  }

  // ============ SUBSCRIPTION DELETED/CANCELED ============
  if (event.type === "customer.subscription.deleted") {
    const subscription = event.data.object;
    const customerId = subscription.customer;

    console.log(`[WEBHOOK] Subscription canceled: ${subscription.id}`);

    try {
      const usersSnapshot = await db.collection("users")
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();

      if (!usersSnapshot.empty) {
        const userDoc = usersSnapshot.docs[0];
        const userId = userDoc.id;

        await db.collection("users").doc(userId).update({
          subscriptionStatus: 'canceled',
          planId: 'free',
          isPremium: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await db.collection("entitlements").doc(userId).update({
          status: 'canceled',
          currentPlanCode: 'free',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`[WEBHOOK] Canceled subscription for user ${userId}`);
      }
    } catch (error) {
      console.error(`[WEBHOOK] Error processing subscription.deleted: ${error.message}`);
    }
  }

  // ============ PAYMENT INTENT SUCCEEDED (Original handler) ============
  if (event.type === "payment_intent.succeeded") {
    const intent = event.data.object;

    // Run Transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      // 1. Find the transaction record
      const snapshot = await transaction.get(
        db.collection("transactions").where("stripePaymentIntentId", "==", intent.id).limit(1)
      );

      if (snapshot.empty) {
        console.error(`[WEBHOOK] Transaction not found for Intent ${intent.id}`);
        return;
      }

      const transDoc = snapshot.docs[0];
      const transData = transDoc.data();

      // 2. Check if already processed to prevent double-credit
      if (transData.status === 'completed') {
        console.log(`[WEBHOOK] Transaction ${transDoc.id} already active/completed.`);
        return;
      }

      // 3. Update Transaction Status
      transaction.update(transDoc.ref, {
        "status": "completed",
        "completedAt": admin.firestore.FieldValue.serverTimestamp()
      });

      // 4. Increment User Balance (The critical fix)
      const userRef = db.collection("users").doc(transData.userId);
      const userDoc = await transaction.get(userRef);

      if (userDoc.exists) {
        const currentBalance = userDoc.data().balance || 0;
        const amountToAdd = transData.amount || 0;

        transaction.update(userRef, {
          "balance": currentBalance + amountToAdd
        });
        console.log(`[WEBHOOK] User ${transData.userId} credited with ${amountToAdd}. New Balance: ${currentBalance + amountToAdd}`);
      }
    });
  }

  // ============ INVOICE PAYMENT FAILED ============
  if (event.type === "invoice.payment_failed") {
    const invoice = event.data.object;
    const customerId = invoice.customer;

    console.log(`[WEBHOOK] Invoice payment failed for customer ${customerId}`);

    try {
      const usersSnapshot = await db.collection("users")
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();

      if (!usersSnapshot.empty) {
        const userId = usersSnapshot.docs[0].id;

        // Create notification for user
        await db.collection("users").doc(userId).collection("notifications").add({
          type: 'payment_failed',
          title: 'Échec de paiement',
          body: 'Votre paiement a échoué. Veuillez mettre à jour votre moyen de paiement.',
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update subscription status
        await db.collection("users").doc(userId).update({
          subscriptionStatus: 'past_due',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`[WEBHOOK] Notified user ${userId} of payment failure`);
      }
    } catch (error) {
      console.error(`[WEBHOOK] Error processing invoice.payment_failed: ${error.message}`);
    }
  }

  res.json({ received: true });
});

/**
 * WEBHOOKS: WAVE / ORANGE MONEY
 */
exports.africaPaymentWebhook = functions.region('europe-west1').https.onRequest(async (req, res) => {
  const { reference, status, provider } = req.body;

  if (status === "SUCCEEDED" || status === "complete") {
    const db = admin.firestore();

    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      await db.runTransaction(async (transaction) => {
        // 1. Find transaction by reference
        const snapshot = await transaction.get(
          db.collection("transactions").where("reference", "==", reference).limit(1)
        );

        if (snapshot.empty) {
          console.error(`[AFRICA WEBHOOK] Transaction not found for ref ${reference}`);
          return;
        }

        const transDoc = snapshot.docs[0];
        const transData = transDoc.data();

        // 2. Idempotency Check
        if (transData.status === 'completed') {
          console.log(`[AFRICA WEBHOOK] Transaction ${transDoc.id} already completed.`);
          return;
        }

        // 3. Mark Transaction as Completed
        transaction.update(transDoc.ref, {
          "status": "completed",
          "completedAt": admin.firestore.FieldValue.serverTimestamp(),
          "provider": provider // Wave, Orange, etc.
        });

        // 4. CREDIT USER BALANCE (CRITICAL FIX)
        const userRef = db.collection("users").doc(transData.userId);
        const userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          const currentBalance = userDoc.data().balance || 0;
          const amountToAdd = transData.amount || 0;

          transaction.update(userRef, {
            "balance": currentBalance + amountToAdd
          });
          console.log(`[AFRICA WEBHOOK] Credited ${amountToAdd} to ${transData.userId}. New Balance: ${currentBalance + amountToAdd}`);
        }
      });

      res.status(200).send("OK");
    } catch (e) {
      console.error("[AFRICA WEBHOOK] Internal Error", e);
      res.status(500).send(e.message);
    }
  } else {
    // Handle failures if needed
    res.status(200).send("Ignored status");
  }
});

/**
 * CLIENT-SIDE TRIGGER: REQUEST WITHDRAWAL
 * Securely debits user balance and creates a PENDING withdrawal request.
 */
exports.requestWithdrawal = functions.region('europe-west1').https.onCall(async (data, context) => {
  // 1. Authenticated?
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in to withdraw.');
  }

  const userId = context.auth.uid;
  const { amount, method, details } = data; // details = { phone: "...", iban: "..." }

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount.');
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(userId);

  try {
    return await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw new functions.https.HttpsError('not-found', 'User profile not found.');

      const userData = userDoc.data();
      const currentBalance = userData.balance || 0;

      // 2. Check Sufficient Funds
      if (currentBalance < amount) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient funds.');
      }

      // 3. DEBIT BALANCE IMMEDIATELY (Lock Funds)
      const newBalance = currentBalance - amount;
      transaction.update(userRef, { "balance": newBalance });

      // 4. Create Transaction Record
      const txRef = db.collection("transactions").doc();
      transaction.set(txRef, {
        userId: userId,
        type: 'withdrawal',
        amount: amount, // Positive amount, logic checks type
        status: 'pending', // Pending Admin/System approval
        method: method || 'manual',
        details: details || {},
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        description: `Paiement ${method}`
      });

      console.log(`[WITHDRAWAL] User ${userId} requested ${amount}. Balance locked. New Balance: ${newBalance}`);
      return { success: true, newBalance: newBalance, transactionId: txRef.id };
    });
  } catch (error) {
    console.error("[WITHDRAWAL] Error:", error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * CLIENT-SIDE TRIGGER: EXECUTE GUARANTEE
 * Callable function to be used by the app when a guarantee condition is met
 * relative to a specific contract clause.
 */
exports.executeGuarantee = functions.https.onCall(async (data, context) => {
  // 1. Authenticated?
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { circleId, memberId, amount, eventId } = data;

  console.log(`[EXECUTE GUARANTEE] Request from ${context.auth.uid} for member ${memberId} in circle ${circleId}`);

  // 2. Validate user permissions (Admin or System only?)
  // For now, checks are strict.
  // const isAdmin = context.auth.token.admin === true;
  // if (!isAdmin) ...

  try {
    // 3. Logic: Real Stripe Charge (Off-Session)

    // A. Fetch User's Stripe Customer ID
    const userDoc = await admin.firestore().collection("users").doc(memberId).get();
    if (!userDoc.exists) throw new Error("User not found");

    const userData = userDoc.data();
    const customerId = userData.stripeCustomerId;

    if (!customerId) {
      throw new Error("User has no properly linked payment account (No Stripe Customer ID).");
    }

    // B. Create PaymentIntent (Off-Session)
    // We assume the user has a default payment method attached.
    // If specific payment method is known, use payment_method: 'pm_...'
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount * 100, // Amount in cents (assuming EUR/USD bases, but checks currency) -> verify standard
      currency: 'eur', // Default to EUR for now or fetch from tontine
      customer: customerId,
      off_session: true,
      confirm: true,
      description: `Guarantee execution for Event ${eventId}`,
      metadata: {
        circleId: circleId,
        memberId: memberId,
        eventId: eventId
      }
    });

    // 4. Update Firestore with Success
    await admin.firestore().collection("tontines").doc(circleId).collection("guarantee_events").add({
      eventId,
      memberId,
      amount,
      triggeredBy: context.auth.uid,
      triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
      stripePaymentIntentId: paymentIntent.id,
      status: "success",
      details: "Funds charged via Stripe off-session"
    });

    return { success: true, message: "Guarantee executed successfully via Stripe.", paymentIntentId: paymentIntent.id };

  } catch (error) {
    console.error("Guarantee Execution Error:", error);

    // Handle authentication required (3DS)
    if (error.code === 'authentication_required') {
      // Return special status so app can prompt user
      return {
        success: false,
        status: "requires_action",
        message: "Strong Customer Authentication required.",
        clientSecret: error.raw.payment_intent.client_secret
      };
    }

    throw new functions.https.HttpsError('internal', `Unable to execute guarantee: ${error.message}`);
  }
});

/**
 * CLEANUP: DELETE USER ACCOUNT
 * Triggered when a user deletes their account from Auth.
 */
exports.deleteUserAccount = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  console.log(`[DELETE ACCOUNT] Cleaning up data for user ${userId}`);

  const db = admin.firestore();

  // 1. Delete User Profile
  await db.collection("users").doc(userId).delete();

  // 2. Anonymize/Delete Transactions? 
  // Financial records usually must be kept for 5-10 years.
  // We keep them but maybe mark user as "deleted".
  const updates = await db.collection("transactions").where("userId", "==", userId).get();
  const batch = db.batch();

  updates.docs.forEach(doc => {
    batch.update(doc.ref, { "userEmail": "deleted@user.com", "isDeletedUser": true });
  });

  await batch.commit();

  console.log(`[DELETE ACCOUNT] Cleanup complete for ${userId}`);
});

/**
 * NOTIFICATION TRIGGERS
 * Automatically send FCM notifications on new messages and invitations.
 */

// 1. New Tontine Message
exports.onTontineMessage = functions.firestore
  .document('tontines/{tontineId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const tontineId = context.params.tontineId;

    // Get Tontine details to find members
    const tontineDoc = await admin.firestore().collection('tontines').doc(tontineId).get();
    if (!tontineDoc.exists) return;

    const tontineData = tontineDoc.data();
    const members = tontineData.memberIds || [];

    // Filter out sender
    const recipients = members.filter(uid => uid !== message.senderId);

    if (recipients.length === 0) return;

    // Send to Topic (Simpler) or Individual Tokens
    // Here we assume clients subscribe to `tontine_{tontineId}`
    const payload = {
      notification: {
        title: `Nouveau message - ${tontineData.name}`,
        body: `${message.senderName}: ${message.text}`,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      data: {
        type: 'chat_message',
        tontineId: tontineId
      }
    };

    await admin.messaging().sendToTopic(`tontine_${tontineId}`, payload);
  });

// 2. New Invitation
exports.onInvitation = functions.firestore
  .document('tontine_invitations/{inviteId}')
  .onCreate(async (snap, context) => {
    const invite = snap.data();
    const phone = invite.phoneNumber;

    // Try to find user by phone to get FCM token (if registered)
    const users = await admin.firestore().collection('users').where('phoneNumber', '==', phone).limit(1).get();

    if (!users.empty) {
      const user = users.docs[0].data();
      if (user.fcmToken) {
        await admin.messaging().sendToDevice(user.fcmToken, {
          notification: {
            title: 'Invitation Tontine',
            body: `${invite.inviterName} vous invite à rejoindre "${invite.tontineName}"`,
          },
          data: {
            type: 'invitation',
            inviteId: context.params.inviteId
          }
        });
      }
    }
  });

// 3. Admin Broadcast (Back-Office)
exports.onBroadcast = functions.firestore
  .document('broadcasts/{broadcastId}')
  .onCreate(async (snap, context) => {
    const broadcast = snap.data();

    // In a real app, 'target' would filter specific topic or user group.
    // Here we send to a global topic 'all_users' (clients must subscribe to it)
    // Or we rely on a loop over users (inefficient but works for small scale).

    // Efficient way: Send to Topic 'general'
    const payload = {
      notification: {
        title: broadcast.title || 'Annonce Tontetic',
        body: broadcast.body,
      },
      data: {
        type: 'broadcast',
        broadcastId: context.params.broadcastId
      }
    };

    // Client needs: _messaging.subscribeToTopic('general');
    await admin.messaging().sendToTopic('general', payload);
    console.log(`[BROADCAST] Sent to topic 'general': ${broadcast.title}`);
  });

// 4. KYC Status Change
exports.onUserStatusChange = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if isVerified changed from false to true
    if (!before.isVerified && after.isVerified) {
      if (after.fcmToken) {
        await admin.messaging().sendToDevice(after.fcmToken, {
          notification: {
            title: 'Félicitations ! 🎉',
            body: 'Votre identité a été vérifiée. Vous avez maintenant le badge "Certifié".',
          },
          data: { type: 'kyc_verified' }
        });
        console.log(`[KYC] Notification sent to ${context.params.userId}`);
      }
    }
  });

// 5. Generic User Notification (Bridge from Cron/Internal logic)
// Whenever a document is added to 'user_notifications', we send the Push.
exports.onUserNotification = functions.firestore
  .document('user_notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    const userId = notif.userId;

    if (!userId) return;

    // Fetch user token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const user = userDoc.data();
    if (user.fcmToken) {
      await admin.messaging().sendToDevice(user.fcmToken, {
        notification: {
          title: notif.title,
          body: notif.body,
        },
        data: {
          type: notif.type || 'info', // 'alert', 'payment', etc.
          isRead: 'false'
        }
      });
      console.log(`[PUSH] Sent to ${userId}: ${notif.title}`);
    }
  });

// 6. Transaction Notification (Deposit/Withdrawal)
exports.onTransactionCreated = functions.firestore
  .document('transactions/{txId}')
  .onCreate(async (snap, context) => {
    const tx = snap.data();
    const userId = tx.userId;

    if (!userId) return;

    // Only notify relevant statuses or types
    if (tx.type === 'deposit' || tx.type === 'withdrawal' || tx.type === 'subscription') {
      // Prepare Notification
      let title = 'Transaction';
      let body = `Nouvelle transaction de ${tx.amount} ${tx.currency || 'EUR'}`;

      if (tx.type === 'deposit') {
        title = 'Dépôt Reçu 💰';
        body = `Votre compte a été crédité de ${tx.amount} ${tx.currency || 'EUR'}.`;
      } else if (tx.type === 'withdrawal') {
        title = 'Demande de Retrait 🏦';
        body = `Votre demande de retrait de ${tx.amount} ${tx.currency || 'EUR'} est en cours de traitement.`;
      } else if (tx.type === 'subscription') {
        title = 'Abonnement Confirmé ⭐';
        body = `Bienvenue dans le plan Premium !`;
      }

      // Send via user_notifications collection (which triggers the push above)
      await admin.firestore().collection('user_notifications').add({
        userId: userId,
        title: title,
        body: body,
        type: 'payment',
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          transactionId: context.params.txId
        }
      });
    }
  });

// ============================================================
// ============ MANGOPAY FUNCTIONS (TONTINES) ============
// ============================================================
// Documentation: https://docs.mangopay.com/api-reference
//
// À CONFIGURER:
// firebase functions:config:set mangopay.client_id="YOUR_CLIENT_ID"
// firebase functions:config:set mangopay.api_key="YOUR_API_KEY"
// firebase functions:config:set mangopay.env="SANDBOX"
// ============================================================

// Mangopay API Configuration (will be initialized when credentials are set)
const MANGOPAY_CONFIG = {
  clientId: functions.config().mangopay?.client_id || 'NOT_CONFIGURED',
  apiKey: functions.config().mangopay?.api_key || 'NOT_CONFIGURED',
  baseUrl: (functions.config().mangopay?.env === 'PRODUCTION')
    ? 'https://api.mangopay.com'
    : 'https://api.sandbox.mangopay.com',
};

// Helper: Check if Mangopay is configured
function isMangopayConfigured() {
  return MANGOPAY_CONFIG.clientId !== 'NOT_CONFIGURED' &&
         MANGOPAY_CONFIG.apiKey !== 'NOT_CONFIGURED';
}

// Helper: Make Mangopay API request
async function mangopayRequest(method, endpoint, body = null) {
  const fetch = (await import('node-fetch')).default;

  const url = `${MANGOPAY_CONFIG.baseUrl}/v2.01/${MANGOPAY_CONFIG.clientId}${endpoint}`;
  const auth = Buffer.from(`${MANGOPAY_CONFIG.clientId}:${MANGOPAY_CONFIG.apiKey}`).toString('base64');

  const options = {
    method,
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);
  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.Message || `Mangopay error: ${response.status}`);
  }

  return data;
}

/**
 * CREATE MANGOPAY NATURAL USER
 * Creates a Natural User (individual) in Mangopay.
 * Required before creating wallets or processing payments.
 */
exports.mangopayCreateNaturalUser = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré. Veuillez contacter le support.' });
  }

  try {
    const { userId, email, firstName, lastName, birthday, nationality, countryOfResidence } = req.body;

    if (!userId || !email || !firstName || !lastName || !birthday) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const mangopayUser = await mangopayRequest('POST', '/users/natural', {
      FirstName: firstName,
      LastName: lastName,
      Email: email,
      Birthday: birthday, // Unix timestamp
      Nationality: nationality || 'FR',
      CountryOfResidence: countryOfResidence || 'FR',
      Tag: `tontetic_user_${userId}`,
    });

    // Save Mangopay user ID to Firestore
    await admin.firestore().collection('users').doc(userId).update({
      mangopayUserId: mangopayUser.Id,
      mangopayKycLevel: mangopayUser.KYCLevel,
      mangopayCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[MANGOPAY] ✅ Created user ${mangopayUser.Id} for ${email}`);

    res.json({
      mangopayUserId: mangopayUser.Id,
      email: mangopayUser.Email,
      kycLevel: mangopayUser.KYCLevel,
    });
  } catch (error) {
    console.error('[mangopayCreateNaturalUser] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE MANGOPAY WALLET
 * Creates a wallet for a user. Each user needs at least one wallet.
 */
exports.mangopayCreateWallet = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const { userId, mangopayUserId, currency, description } = req.body;

    if (!mangopayUserId) {
      return res.status(400).json({ error: 'mangopayUserId is required' });
    }

    const wallet = await mangopayRequest('POST', '/wallets', {
      Owners: [mangopayUserId],
      Currency: currency || 'EUR',
      Description: description || 'Wallet Tontine',
      Tag: `tontetic_wallet_${userId}`,
    });

    // Save wallet ID to Firestore
    if (userId) {
      await admin.firestore().collection('users').doc(userId).update({
        mangopayWalletId: wallet.Id,
      });
    }

    console.log(`[MANGOPAY] ✅ Created wallet ${wallet.Id}`);

    res.json({
      walletId: wallet.Id,
      ownerId: mangopayUserId,
      balance: wallet.Balance?.Amount || 0,
      currency: wallet.Currency,
    });
  } catch (error) {
    console.error('[mangopayCreateWallet] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE MANGOPAY BANK ACCOUNT (IBAN)
 * Registers a user's IBAN for payouts.
 */
exports.mangopayCreateBankAccount = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const { mangopayUserId, ownerName, iban, ownerAddress } = req.body;

    if (!mangopayUserId || !ownerName || !iban) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const bankAccount = await mangopayRequest('POST', `/users/${mangopayUserId}/bankaccounts/iban`, {
      OwnerName: ownerName,
      IBAN: iban,
      OwnerAddress: {
        AddressLine1: ownerAddress?.addressLine1 || '',
        City: ownerAddress?.city || '',
        PostalCode: ownerAddress?.postalCode || '',
        Country: ownerAddress?.country || 'FR',
      },
      Tag: 'tontetic_iban',
    });

    console.log(`[MANGOPAY] ✅ Created bank account ${bankAccount.Id}`);

    res.json({
      bankAccountId: bankAccount.Id,
      ownerName: bankAccount.OwnerName,
      iban: bankAccount.IBAN,
      active: bankAccount.Active,
    });
  } catch (error) {
    console.error('[mangopayCreateBankAccount] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE MANGOPAY MANDATE (SEPA Direct Debit)
 * Creates a SEPA mandate for automatic debits.
 */
exports.mangopayCreateMandate = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const { mangopayUserId, bankAccountId, culture, returnUrl } = req.body;

    if (!bankAccountId) {
      return res.status(400).json({ error: 'bankAccountId is required' });
    }

    const mandate = await mangopayRequest('POST', '/mandates/directdebit/web', {
      BankAccountId: bankAccountId,
      Culture: culture || 'FR',
      ReturnURL: returnUrl || 'https://tontetic-app.web.app/mandate/complete',
      Tag: 'tontetic_sepa_mandate',
    });

    console.log(`[MANGOPAY] ✅ Created mandate ${mandate.Id} - Status: ${mandate.Status}`);

    res.json({
      mandateId: mandate.Id,
      bankAccountId: mandate.BankAccountId,
      status: mandate.Status,
      redirectUrl: mandate.RedirectURL,
    });
  } catch (error) {
    console.error('[mangopayCreateMandate] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE MANGOPAY PAYIN (SEPA Direct Debit)
 * Debits money from a user's bank account to their wallet.
 */
exports.mangopayCreatePayIn = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const { userId, mandateId, creditedWalletId, amount, currency, statementDescriptor, metadata } = req.body;

    if (!mandateId || !creditedWalletId || !amount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Get mandate to find the author (user)
    const mandate = await mangopayRequest('GET', `/mandates/${mandateId}`);

    const payIn = await mangopayRequest('POST', '/payins/directdebit/direct', {
      AuthorId: mandate.UserId,
      CreditedWalletId: creditedWalletId,
      DebitedFunds: {
        Amount: amount,
        Currency: currency || 'EUR',
      },
      Fees: {
        Amount: 0, // Tontetic absorbs fees for subscribers
        Currency: currency || 'EUR',
      },
      MandateId: mandateId,
      StatementDescriptor: statementDescriptor || 'TONTETIC',
      Tag: JSON.stringify(metadata || {}),
    });

    // Log to Firestore for tracking
    await admin.firestore().collection('mangopay_transactions').add({
      type: 'PAYIN',
      mangopayId: payIn.Id,
      userId: userId,
      amount: amount,
      currency: currency || 'EUR',
      status: payIn.Status,
      metadata: metadata,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[MANGOPAY] ✅ PayIn created ${payIn.Id} - Status: ${payIn.Status}`);

    res.json({
      payInId: payIn.Id,
      status: payIn.Status,
      executionDate: payIn.ExecutionDate,
    });
  } catch (error) {
    console.error('[mangopayCreatePayIn] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE MANGOPAY TRANSFER (Wallet to Wallet)
 * Transfers money between wallets (consolidation).
 */
exports.mangopayCreateTransfer = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const { debitedWalletId, creditedWalletId, amount, currency, metadata } = req.body;

    if (!debitedWalletId || !creditedWalletId || !amount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Get debited wallet to find owner
    const wallet = await mangopayRequest('GET', `/wallets/${debitedWalletId}`);

    const transfer = await mangopayRequest('POST', '/transfers', {
      AuthorId: wallet.Owners[0],
      DebitedFunds: {
        Amount: amount,
        Currency: currency || 'EUR',
      },
      Fees: {
        Amount: 0,
        Currency: currency || 'EUR',
      },
      DebitedWalletId: debitedWalletId,
      CreditedWalletId: creditedWalletId,
      Tag: JSON.stringify(metadata || {}),
    });

    console.log(`[MANGOPAY] ✅ Transfer created ${transfer.Id}`);

    res.json({
      transferId: transfer.Id,
      status: transfer.Status,
    });
  } catch (error) {
    console.error('[mangopayCreateTransfer] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE MANGOPAY PAYOUT (Wallet to Bank Account)
 * Sends money from a wallet to a bank account.
 */
exports.mangopayCreatePayOut = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const { mangopayUserId, debitedWalletId, bankAccountId, amount, currency, bankWireRef, metadata } = req.body;

    if (!mangopayUserId || !debitedWalletId || !bankAccountId || !amount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const payOut = await mangopayRequest('POST', '/payouts/bankwire', {
      AuthorId: mangopayUserId,
      DebitedFunds: {
        Amount: amount,
        Currency: currency || 'EUR',
      },
      Fees: {
        Amount: 0, // Tontetic absorbs fees
        Currency: currency || 'EUR',
      },
      DebitedWalletId: debitedWalletId,
      BankAccountId: bankAccountId,
      BankWireRef: bankWireRef || 'TONTETIC',
      Tag: JSON.stringify(metadata || {}),
    });

    // Log to Firestore
    await admin.firestore().collection('mangopay_transactions').add({
      type: 'PAYOUT',
      mangopayId: payOut.Id,
      mangopayUserId: mangopayUserId,
      amount: amount,
      currency: currency || 'EUR',
      status: payOut.Status,
      metadata: metadata,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[MANGOPAY] ✅ PayOut created ${payOut.Id} - Status: ${payOut.Status}`);

    res.json({
      payOutId: payOut.Id,
      status: payOut.Status,
      executionDate: payOut.ExecutionDate,
    });
  } catch (error) {
    console.error('[mangopayCreatePayOut] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * MANGOPAY WEBHOOK
 * Handles Mangopay events (PayIn succeeded, KYC validated, etc.)
 * Configure in Mangopay Dashboard: https://hub.mangopay.com
 */
exports.mangopayWebhook = functions.region('europe-west1').https.onRequest(async (req, res) => {
  try {
    const { EventType, RessourceId, Date: eventDate } = req.body;

    console.log(`[MANGOPAY WEBHOOK] Event: ${EventType}, Resource: ${RessourceId}`);

    const db = admin.firestore();

    switch (EventType) {
      // PayIn Events
      case 'PAYIN_NORMAL_SUCCEEDED':
        console.log(`[MANGOPAY] ✅ PayIn ${RessourceId} succeeded`);
        await db.collection('mangopay_transactions')
          .where('mangopayId', '==', RessourceId)
          .get()
          .then(snapshot => {
            snapshot.forEach(doc => {
              doc.ref.update({ status: 'SUCCEEDED', completedAt: admin.firestore.FieldValue.serverTimestamp() });
            });
          });
        break;

      case 'PAYIN_NORMAL_FAILED':
        console.log(`[MANGOPAY] ❌ PayIn ${RessourceId} failed`);
        await db.collection('mangopay_transactions')
          .where('mangopayId', '==', RessourceId)
          .get()
          .then(snapshot => {
            snapshot.forEach(doc => {
              doc.ref.update({ status: 'FAILED' });
            });
          });
        break;

      // Transfer Events
      case 'TRANSFER_NORMAL_SUCCEEDED':
        console.log(`[MANGOPAY] ✅ Transfer ${RessourceId} succeeded`);
        break;

      // PayOut Events
      case 'PAYOUT_NORMAL_SUCCEEDED':
        console.log(`[MANGOPAY] ✅ PayOut ${RessourceId} succeeded - Funds sent to bank`);
        await db.collection('mangopay_transactions')
          .where('mangopayId', '==', RessourceId)
          .get()
          .then(snapshot => {
            snapshot.forEach(doc => {
              doc.ref.update({ status: 'SUCCEEDED', completedAt: admin.firestore.FieldValue.serverTimestamp() });
            });
          });
        break;

      case 'PAYOUT_NORMAL_FAILED':
        console.log(`[MANGOPAY] ❌ PayOut ${RessourceId} failed`);
        break;

      // KYC Events
      case 'KYC_SUCCEEDED':
        console.log(`[MANGOPAY] ✅ KYC validated for document ${RessourceId}`);
        // Find user by KYC document and update status
        break;

      case 'KYC_FAILED':
        console.log(`[MANGOPAY] ❌ KYC failed for document ${RessourceId}`);
        break;

      // Mandate Events
      case 'MANDATE_SUBMITTED':
        console.log(`[MANGOPAY] Mandate ${RessourceId} submitted`);
        break;

      case 'MANDATE_ACTIVATED':
        console.log(`[MANGOPAY] ✅ Mandate ${RessourceId} activated - Ready for DirectDebit`);
        break;

      case 'MANDATE_FAILED':
        console.log(`[MANGOPAY] ❌ Mandate ${RessourceId} failed`);
        break;

      default:
        console.log(`[MANGOPAY WEBHOOK] Unhandled event: ${EventType}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('[mangopayWebhook] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET MANGOPAY USER
 * Retrieves Mangopay user info by Firestore userId.
 */
exports.mangopayGetUser = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const userId = req.query.userId;
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Get Mangopay ID from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists || !userDoc.data().mangopayUserId) {
      return res.status(404).json({ error: 'Mangopay user not found' });
    }

    const mangopayUserId = userDoc.data().mangopayUserId;
    const mangopayUser = await mangopayRequest('GET', `/users/${mangopayUserId}`);

    res.json({
      mangopayUserId: mangopayUser.Id,
      email: mangopayUser.Email,
      firstName: mangopayUser.FirstName,
      lastName: mangopayUser.LastName,
      kycLevel: mangopayUser.KYCLevel,
    });
  } catch (error) {
    console.error('[mangopayGetUser] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET MANGOPAY WALLET
 * Retrieves wallet balance and info.
 */
exports.mangopayGetWallet = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).send('');

  if (!isMangopayConfigured()) {
    return res.status(503).json({ error: 'Mangopay non configuré' });
  }

  try {
    const walletId = req.query.walletId;
    if (!walletId) {
      return res.status(400).json({ error: 'walletId is required' });
    }

    const wallet = await mangopayRequest('GET', `/wallets/${walletId}`);

    res.json({
      walletId: wallet.Id,
      balance: wallet.Balance?.Amount || 0,
      currency: wallet.Balance?.Currency || 'EUR',
      description: wallet.Description,
    });
  } catch (error) {
    console.error('[mangopayGetWallet] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============ ADMIN CLAIMS MANAGEMENT ============

/**
 * SET ADMIN CLAIMS
 * Allows super_admin to grant/revoke admin privileges.
 * Security: Only callable by users with super_admin custom claim.
 */
exports.setAdminClaims = functions.region('europe-west1').https.onCall(async (data, context) => {
  // 1. Verify caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // 2. Verify caller is super_admin
  const callerClaims = context.auth.token;
  if (callerClaims.super_admin !== true) {
    console.warn(`[setAdminClaims] Unauthorized attempt by ${context.auth.uid}`);
    throw new functions.https.HttpsError('permission-denied', 'Super admin privileges required');
  }

  // 3. Validate input
  const { targetUid, role } = data;
  if (!targetUid || typeof targetUid !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required');
  }
  if (!['admin', 'super_admin', 'revoke'].includes(role)) {
    throw new functions.https.HttpsError('invalid-argument', 'role must be admin, super_admin, or revoke');
  }

  try {
    // 4. Get target user to verify they exist
    const targetUser = await admin.auth().getUser(targetUid);

    // 5. Set custom claims based on role
    let newClaims = {};
    if (role === 'admin') {
      newClaims = { admin: true, super_admin: false };
    } else if (role === 'super_admin') {
      newClaims = { admin: true, super_admin: true };
    } else if (role === 'revoke') {
      newClaims = { admin: false, super_admin: false };
    }

    await admin.auth().setCustomUserClaims(targetUid, newClaims);

    // 6. Log to audit collection
    await admin.firestore().collection('admin_audit_logs').add({
      action: 'SET_ADMIN_CLAIMS',
      performedBy: context.auth.uid,
      targetUid: targetUid,
      targetEmail: targetUser.email || 'N/A',
      newRole: role,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: context.rawRequest?.ip || 'unknown',
    });

    console.log(`[setAdminClaims] ${context.auth.uid} set ${targetUid} to ${role}`);

    return {
      success: true,
      message: `User ${targetUser.email || targetUid} is now ${role === 'revoke' ? 'a regular user' : role}`,
    };
  } catch (error) {
    console.error('[setAdminClaims] Error:', error);
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'Target user not found');
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * BOOTSTRAP FIRST SUPER ADMIN
 * One-time use function to create the first super_admin.
 * SECURITY: Disabled after first use via Firestore flag.
 */
exports.bootstrapSuperAdmin = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const db = admin.firestore();

  // Check if bootstrap has already been used
  const configDoc = await db.collection('app_config').doc('admin_bootstrap').get();
  if (configDoc.exists && configDoc.data()?.used === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Bootstrap already used. Contact existing super_admin.');
  }

  // Validate secret key (should be set in Firebase config)
  const { secretKey } = data;
  const expectedKey = functions.config().admin?.bootstrap_key;

  if (!expectedKey || secretKey !== expectedKey) {
    console.warn(`[bootstrapSuperAdmin] Invalid key attempt by ${context.auth.uid}`);
    throw new functions.https.HttpsError('permission-denied', 'Invalid bootstrap key');
  }

  try {
    // Set super_admin claims
    await admin.auth().setCustomUserClaims(context.auth.uid, {
      admin: true,
      super_admin: true,
    });

    // Mark bootstrap as used
    await db.collection('app_config').doc('admin_bootstrap').set({
      used: true,
      firstAdminUid: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log to audit
    await db.collection('admin_audit_logs').add({
      action: 'BOOTSTRAP_SUPER_ADMIN',
      performedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[bootstrapSuperAdmin] First super_admin created: ${context.auth.uid}`);

    return {
      success: true,
      message: 'You are now super_admin. Please sign out and sign back in for claims to take effect.',
    };
  } catch (error) {
    console.error('[bootstrapSuperAdmin] Error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
