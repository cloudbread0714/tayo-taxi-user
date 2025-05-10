const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.copyRecentRideRequests = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const tenMinutesAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 10 * 60 * 1000
    );

    const snapshot = await db
      .collection("ride_requests")
      .where("createdAt", ">=", tenMinutesAgo)
      .get();

    const batch = db.batch();

    snapshot.forEach((doc) => {
      const ref = db.collection("recent_ride_requests").doc(doc.id);
      batch.set(ref, {
        ...doc.data(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          now.toMillis() + 10 * 60 * 1000
        ),
      });
    });

    await batch.commit();
    console.log(`✔ Copied ${snapshot.size} recent ride requests`);
  });