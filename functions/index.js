const functions = require("firebase-functions"); // ✅ v1 안정 버전
const admin = require("firebase-admin");
admin.initializeApp();

// 예시 Cloud Function
exports.copyRecentRideRequests = functions.pubsub
  .schedule("every 5 minutes")
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
      batch.set(ref, doc.data());
    });

    await batch.commit();
    console.log(`✔ Copied ${snapshot.size} recent requests`);
  });
