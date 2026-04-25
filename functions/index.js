const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Deletes a user from both Firebase Auth and Firestore.
 * This can only be called by a Super Admin.
 */
exports.deleteUserAuth = onCall(async (request) => {
  const { data, auth } = request;

  // 1. Security Check: Must be authenticated
  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  // 2. Security Check: Must be Super Admin
  const callerUid = auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  
  if (!callerDoc.exists || callerDoc.data().role !== "Super Admin") {
    throw new HttpsError(
      "permission-denied",
      "Only Super Admins can delete other users."
    );
  }

  const targetUid = data.uid;
  if (!targetUid) {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with a target 'uid'."
    );
  }

  console.log(`Super Admin ${callerUid} is deleting user ${targetUid}`);

  try {
    // 3. Delete from Firebase Auth
    await admin.auth().deleteUser(targetUid);
    console.log(`Successfully deleted auth record for ${targetUid}`);

    // 4. Delete from Firestore (users collection)
    await admin.firestore().collection("users").doc(targetUid).delete();
    console.log(`Successfully deleted firestore record for ${targetUid}`);

    // 5. Cleanup related data (optional: store employees, etc.)
    const storesSnap = await admin.firestore().collection("stores").get();
    const batch = admin.firestore().batch();
    
    for (const storeDoc of storesSnap.docs) {
      const empRef = storeDoc.ref.collection("employees").doc(targetUid);
      const empDoc = await empRef.get();
      if (empDoc.exists) {
        batch.delete(empRef);
      }
    }
    
    await batch.commit();

    return { success: true, message: `User ${targetUid} deleted successfully.` };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new HttpsError("internal", error.message);
  }
});
