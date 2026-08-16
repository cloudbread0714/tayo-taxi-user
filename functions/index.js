const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const geminiApiKey = defineSecret("GOOGLE_GEMINI_API_KEY");
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/" +
  "gemini-1.5-flash:generateContent";
const MAX_INPUT_LENGTH = 500;

/**
 * Extracts a Korean place name from speech text using Gemini.
 * The API key is stored as a Function secret, not in the client app.
 */
exports.extractPlaceName = onCall(
    {
      region: "asia-northeast3",
      secrets: [geminiApiKey],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const inputText = request.data && request.data.inputText;
      if (typeof inputText !== "string" || inputText.trim().length < 2) {
        throw new HttpsError("invalid-argument", "inputText is required.");
      }
      if (inputText.length > MAX_INPUT_LENGTH) {
        throw new HttpsError("invalid-argument", "inputText is too long.");
      }

      const prompt =
        "다음 문장에서 한국어 장소명만 추출해 주세요. " +
        "장소가 없으면 'NONE'이라고만 말해주세요: '" +
        inputText.trim() +
        "'";

      let response;
      try {
        response = await fetch(
            GEMINI_URL + "?key=" + geminiApiKey.value(),
            {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify({
                contents: [{parts: [{text: prompt}]}],
              }),
            },
        );
      } catch (error) {
        throw new HttpsError("internal", "Place extraction failed.");
      }

      if (!response.ok) {
        throw new HttpsError("internal", "Place extraction failed.");
      }

      const payload = await response.json();
      const text =
        payload &&
        payload.candidates &&
        payload.candidates[0] &&
        payload.candidates[0].content &&
        payload.candidates[0].content.parts &&
        payload.candidates[0].content.parts[0] &&
        payload.candidates[0].content.parts[0].text;

      if (typeof text !== "string") {
        return {place: null};
      }

      const cleaned = text.replace(/\n/g, "").trim();
      if (!cleaned || cleaned.toLowerCase() === "none") {
        return {place: null};
      }
      return {place: cleaned};
    },
);
