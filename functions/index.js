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

const crypto = require("crypto");

function hashPin(pin, uid) {
  if (!pin || !uid) return "";
  return crypto.createHash("sha256").update(pin + uid).digest("hex");
}

/**
 * Validates employee credentials against server records,
 * ensures membership is ACTIVE, hashes legacy plaintext PINs,
 * and issues a custom Firebase Auth token scoped to the store.
 */
exports.verifyEmployeePin = onCall(async (request) => {
  const { storeId, storeCode, employeeId, pin } = request.data || {};

  if (!pin || !employeeId) {
    throw new HttpsError(
      "invalid-argument",
      "Both 'employeeId' and 'pin' are required."
    );
  }

  const db = admin.firestore();

  // 1. Resolve Store
  let targetStoreId = storeId;
  if (!targetStoreId && storeCode) {
    const cleanCode = storeCode.replace(/[^a-zA-Z0-9]/g, "");
    const storeQuery = await db
      .collection("stores")
      .where("shortCode", "==", cleanCode)
      .limit(1)
      .get();

    if (!storeQuery.empty) {
      targetStoreId = storeQuery.docs[0].id;
    } else {
      const storeDoc = await db.collection("stores").doc(cleanCode).get();
      if (storeDoc.exists) {
        targetStoreId = cleanCode;
      }
    }
  }

  if (!targetStoreId) {
    throw new HttpsError("not-found", "Store could not be resolved.");
  }

  const storeDoc = await db.collection("stores").doc(targetStoreId).get();
  if (!storeDoc.exists) {
    throw new HttpsError("not-found", "Store not found.");
  }

  // 2. Locate Employee Document
  let empDoc = null;
  let empData = null;
  let empUid = null;

  // 2a. Check subcollection stores/{storeId}/employees
  const subQuery = await db
    .collection("stores")
    .doc(targetStoreId)
    .collection("employees")
    .where("employeeId", "==", String(employeeId))
    .limit(1)
    .get();

  if (!subQuery.empty) {
    empDoc = subQuery.docs[0];
    empData = empDoc.data();
    empUid = empDoc.id;
  } else {
    // Check with numeric employeeId
    const numId = parseInt(employeeId, 10);
    if (!isNaN(numId)) {
      const subNumQuery = await db
        .collection("stores")
        .doc(targetStoreId)
        .collection("employees")
        .where("employeeId", "==", numId)
        .limit(1)
        .get();
      if (!subNumQuery.empty) {
        empDoc = subNumQuery.docs[0];
        empData = empDoc.data();
        empUid = empDoc.id;
      }
    }
  }

  // 2b. Check root employees collection
  if (!empDoc) {
    const rootQuery = await db
      .collection("employees")
      .where("storeId", "==", targetStoreId)
      .where("employeeId", "==", String(employeeId))
      .limit(1)
      .get();
    if (!rootQuery.empty) {
      empDoc = rootQuery.docs[0];
      empData = empDoc.data();
      empUid = empDoc.id;
    }
  }

  // 2c. Check root users collection (legacy email pattern)
  if (!empDoc) {
    const dummyEmail = `${targetStoreId}_${employeeId}@biztonic.pos`.toLowerCase();
    const userQuery = await db
      .collection("users")
      .where("email", "==", dummyEmail)
      .limit(1)
      .get();
    if (!userQuery.empty) {
      empDoc = userQuery.docs[0];
      empData = empDoc.data();
      empUid = empDoc.id;
    }
  }

  if (!empDoc || !empData) {
    throw new HttpsError("not-found", "Employee profile not found.");
  }

  // 3. Verify Server-Controlled Membership Status
  const memberRef = db
    .collection("stores")
    .doc(targetStoreId)
    .collection("members")
    .doc(empUid);
  const memberDoc = await memberRef.get();

  if (memberDoc.exists) {
    const memberData = memberDoc.data();
    if (memberData.status === "REMOVED" || memberData.status === "SUSPENDED") {
      throw new HttpsError(
        "permission-denied",
        `Employee access has been ${memberData.status.toLowerCase()}.`
      );
    }
  }

  // 4. Verify PIN Hash (Salted SHA-256 with empUid)
  const expectedHash = hashPin(String(pin).trim(), empUid);
  const storedHash = empData.pinHash || empData.pin_hash;
  const storedPlainPin = empData.pin;

  let isValid = false;
  if (storedHash && storedHash === expectedHash) {
    isValid = true;
  } else if (storedPlainPin && String(storedPlainPin).trim() === String(pin).trim()) {
    isValid = true;
    // Migrate plaintext PIN to salted hash immediately
    await empDoc.ref.update({
      pinHash: expectedHash,
      pin: admin.firestore.FieldValue.delete(),
    });
  }

  if (!isValid) {
    throw new HttpsError("permission-denied", "Invalid PIN.");
  }

  // 5. Ensure Server-Controlled Membership Record is ACTIVE
  const role = empData.role || "Cashier";
  if (!memberDoc.exists) {
    await memberRef.set({
      uid: empUid,
      storeId: targetStoreId,
      role: role,
      status: "ACTIVE",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else if (memberDoc.data().status !== "ACTIVE") {
    await memberRef.update({
      status: "ACTIVE",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 6. Issue Firebase Custom Auth Token with Store Claims
  const customClaims = {
    storeId: targetStoreId,
    role: role,
    isEmployee: true,
  };

  const customToken = await admin.auth().createCustomToken(empUid, customClaims);

  return {
    success: true,
    token: customToken,
    employee: {
      uid: empUid,
      name: empData.name || "Employee",
      role: role,
      storeId: targetStoreId,
      employeeId: empData.employeeId,
      permissions: empData.permissions || {},
    },
  };
});

/**
 * Migration Function: Populates stores/{storeId}/members/{uid},
 * registers Super Admins in /platform_admins, and cleans up plaintext PINs.
 * Callable by Super Admin.
 */
exports.migrateMemberships = onCall(async (request) => {
  const { auth } = request;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const db = admin.firestore();

  // Validate caller is Super Admin
  const callerDoc = await db.collection("users").doc(auth.uid).get();
  const callerIsAdmin = callerDoc.exists && 
    (callerDoc.data().role === "Super Admin" || callerDoc.data().role === "super_admin");
  const callerEmailMatch = auth.token && auth.token.email && (
    auth.token.email.toLowerCase() === "pthorat600@gmail.com" ||
    auth.token.email.toLowerCase() === "biztonicautomation@gmail.com"
  );

  if (!callerIsAdmin && !callerEmailMatch) {
    throw new HttpsError("permission-denied", "Super Admin access required.");
  }

  let storesMigrated = 0;
  let membersCreated = 0;
  let adminsRegistered = 0;
  let pinsHashed = 0;

  // 1. Register Platform Admins
  const usersSnap = await db.collection("users").get();
  for (const userDoc of usersSnap.docs) {
    const data = userDoc.data();
    if (data.role === "Super Admin" || data.role === "super_admin") {
      await db.collection("platform_admins").doc(userDoc.id).set({
        uid: userDoc.id,
        email: data.email || "",
        status: "ACTIVE",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      adminsRegistered++;
    }

    // Convert legacy plaintext PINs
    if (data.pin && !data.pinHash) {
      const computedHash = hashPin(String(data.pin).trim(), userDoc.id);
      await userDoc.ref.update({
        pinHash: computedHash,
        pin: admin.firestore.FieldValue.delete(),
      });
      pinsHashed++;
    }
  }

  // 2. Migrate Store Owners and Members
  const storesSnap = await db.collection("stores").get();
  for (const storeDoc of storesSnap.docs) {
    const storeId = storeDoc.id;
    const storeData = storeDoc.data();
    const ownerUid = storeData.owner;

    if (ownerUid) {
      await db.collection("stores").doc(storeId).collection("members").doc(ownerUid).set({
        uid: ownerUid,
        storeId: storeId,
        role: "Owner",
        status: "ACTIVE",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      membersCreated++;
    }

    // Migrate Subcollection Employees
    const empSnap = await storeDoc.ref.collection("employees").get();
    for (const empDoc of empSnap.docs) {
      const empData = empDoc.data();
      const empUid = empDoc.id;

      await db.collection("stores").doc(storeId).collection("members").doc(empUid).set({
        uid: empUid,
        storeId: storeId,
        role: empData.role || "Cashier",
        status: empData.status || "ACTIVE",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      membersCreated++;

      if (empData.pin && !empData.pinHash) {
        const computedHash = hashPin(String(empData.pin).trim(), empUid);
        await empDoc.ref.update({
          pinHash: computedHash,
          pin: admin.firestore.FieldValue.delete(),
        });
        pinsHashed++;
      }
    }

    storesMigrated++;
  }

  return {
    success: true,
    storesMigrated,
    membersCreated,
    adminsRegistered,
    pinsHashed,
  };
});

