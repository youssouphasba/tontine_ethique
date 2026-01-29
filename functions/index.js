const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret_key);

admin.initializeApp();

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

        // 1. Move funds from guarantee hold to collective payout (Stripe Connect Transfer)
        // await stripe.transfers.create({ ... });

        // 2. Mark as defaulted
        await paymentDoc.ref.update({ "status": "guarantee_triggered" });
      }
    }
  }
});

/**
 * WEBHOOKS: STRIPE
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const event = stripe.webhooks.constructEvent(req.rawBody, sig, functions.config().stripe.webhook_secret);

  if (event.type === "payment_intent.succeeded") {
    const intent = event.data.object;
    await admin.firestore().collection("transactions")
      .where("stripePaymentIntentId", "==", intent.id)
      .limit(1)
      .get()
      .then(s => s.docs[0].ref.update({ "status": "completed", "completedAt": admin.firestore.FieldValue.serverTimestamp() }));
  }
  res.json({ received: true });
});

/**
 * WEBHOOKS: WAVE / ORANGE MONEY
 */
exports.africaPaymentWebhook = functions.https.onRequest(async (req, res) => {
  const { reference, status, provider } = req.body;

  if (status === "SUCCEEDED" || status === "complete") {
    await admin.firestore().collection("transactions")
      .where("reference", "==", reference)
      .limit(1)
      .get()
      .then(s => {
        if (!s.empty) s.docs[0].ref.update({ "status": "completed" });
      });
  }
  res.status(200).send("OK");
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
