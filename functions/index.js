const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.copyRecentRideRequests = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    console.log("recent_ride_requests 복사 기능은 비활성화됨.");
    return null;
  });