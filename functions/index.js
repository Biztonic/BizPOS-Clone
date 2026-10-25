const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

async function isCallerSuperAdmin(auth, db) {
  if (!auth) return false;
  // 1. Custom token claims
  if (auth.token && (auth.token.role === "super_admin" || auth.token.isSuperAdmin === true)) {
    return true;
  }
  // 2. Server-controlled platform_admins collection
  const adminDoc = await db.collection("platform_admins").doc(auth.uid).get();
  if (adminDoc.exists && adminDoc.data().status === "ACTIVE") {
    return true;
  }
  // 3. Backward compatible check against users doc
  const callerDoc = await db.collection("users").doc(auth.uid).get();
  if (callerDoc.exists && (callerDoc.data().role === "Super Admin" || callerDoc.data().role === "super_admin")) {
    return true;
  }
  return false;
}

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
  const db = admin.firestore();
  const callerIsAdmin = await isCallerSuperAdmin(auth, db);
  
  if (!callerIsAdmin) {
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
  const callerIsAdmin = await isCallerSuperAdmin(auth, db);

  if (!callerIsAdmin) {
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

// ─────────────────────────────────────────────────────────────
// SERVER-AUTHORITATIVE SUBSCRIPTION & ENTITLEMENT MANAGEMENT
// ─────────────────────────────────────────────────────────────

const DEFAULT_PLAN_FEATURES = {
  Starting: ["billing", "basic_inventory"],
  Basic: ["billing", "inventory", "customers", "basic_reports", "orders"],
  Standard: [
    "billing",
    "inventory",
    "customers",
    "employees",
    "reports",
    "tables",
    "floors",
    "suppliers",
    "orders",
    "data_center",
  ],
  Professional: [
    "billing",
    "inventory",
    "customers",
    "employees",
    "reports",
    "tables",
    "floors",
    "suppliers",
    "orders",
    "advanced_reports",
    "multi_store",
    "api_access",
    "data_center",
  ],
  Enterprise: ["*"],
};

const DEFAULT_PLAN_LIMITS = {
  Starting: {
    orders: 50,
    dailyOrders: 20,
    monthlyOrders: 50,
    inventory: 30,
    customers: 20,
    employees: 2,
    stores: 1,
  },
  Basic: {
    orders: 500,
    dailyOrders: 50,
    monthlyOrders: 1500,
    inventory: 200,
    customers: 100,
    employees: 5,
    stores: 1,
  },
  Standard: {
    orders: -1,
    dailyOrders: -1,
    monthlyOrders: -1,
    inventory: -1,
    customers: -1,
    employees: 15,
    stores: 3,
  },
  Professional: {
    orders: -1,
    dailyOrders: -1,
    monthlyOrders: -1,
    inventory: -1,
    customers: -1,
    employees: -1,
    stores: 10,
  },
  Enterprise: {
    orders: -1,
    dailyOrders: -1,
    monthlyOrders: -1,
    inventory: -1,
    customers: -1,
    employees: -1,
    stores: -1,
  },
};

function computeEntitlementHash({
  storeId,
  plan,
  status,
  version,
  addons = [],
  purchasedAddons = [],
  limits = {},
  features = [],
  endDate = null,
  serverTimestamp = null,
}) {
  const sortedAddons = [...addons].sort();
  const sortedPurchased = [...purchasedAddons].sort();
  const sortedFeatures = [...features].sort();
  const sortedLimitsKeys = Object.keys(limits).sort();
  const limitsStr = sortedLimitsKeys.map((k) => `${k}:${limits[k]}`).join(",");

  const endMs = endDate
    ? endDate.toDate
      ? endDate.toDate().getTime()
      : new Date(endDate).getTime()
    : "none";
  const serverMs = serverTimestamp
    ? serverTimestamp.toDate
      ? serverTimestamp.toDate().getTime()
      : new Date(serverTimestamp).getTime()
    : "none";

  const payload = [
    storeId,
    plan,
    status,
    String(version),
    sortedAddons.join(","),
    sortedPurchased.join(","),
    limitsStr,
    sortedFeatures.join(","),
    String(endMs),
    String(serverMs),
    "BIZPOS_ENTITLEMENT_SALT_V1",
  ].join("|");

  return crypto.createHash("sha256").update(payload, "utf8").digest("hex");
}

/**
 * Server-authoritative subscription activation.
 * Callable strictly by Super Admins.
 */
exports.activateSubscription = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const db = admin.firestore();
  const callerIsAdmin = await isCallerSuperAdmin(auth, db);
  if (!callerIsAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Only Super Admins can activate subscriptions."
    );
  }

  const {
    storeId,
    planType = "Standard",
    durationDays = 30,
    billingCycle = "monthly",
    price = 0.0,
    selectedAddons = [],
    requestId = null,
  } = data || {};

  if (!storeId) {
    throw new HttpsError("invalid-argument", "'storeId' is required.");
  }

  const storeRef = db.collection("stores").doc(storeId);
  const storeSnap = await storeRef.get();
  if (!storeSnap.exists) {
    throw new HttpsError("not-found", `Store '${storeId}' not found.`);
  }

  const storeData = storeSnap.data();
  const now = new Date();
  const expiryDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
  const currentVersion = (storeData.entitlementVersion || 0) + 1;

  // Merge purchased addons
  const existingPurchased = new Set(storeData.purchasedAddons || []);
  for (const a of selectedAddons) existingPurchased.add(a);
  const updatedPurchased = Array.from(existingPurchased);

  const existingAddons = new Set(storeData.addons || []);
  for (const a of selectedAddons) existingAddons.add(a);
  const updatedAddons = Array.from(existingAddons);

  const limits = DEFAULT_PLAN_LIMITS[planType] || DEFAULT_PLAN_LIMITS.Basic;
  const features = DEFAULT_PLAN_FEATURES[planType] || DEFAULT_PLAN_FEATURES.Basic;

  const tamperHash = computeEntitlementHash({
    storeId,
    plan: planType,
    status: "ACTIVE",
    version: currentVersion,
    addons: updatedAddons,
    purchasedAddons: updatedPurchased,
    limits,
    features,
    endDate: expiryTimestamp,
    serverTimestamp: admin.firestore.Timestamp.fromDate(now),
  });

  const canonicalEntitlement = {
    storeId,
    plan: planType,
    status: "ACTIVE",
    startDate: admin.firestore.FieldValue.serverTimestamp(),
    endDate: expiryTimestamp,
    gracePeriodDays: 7,
    addons: updatedAddons,
    purchasedAddons: updatedPurchased,
    limits,
    features,
    version: currentVersion,
    tamperHash,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();

  // 1. Update Store Root Document
  batch.update(storeRef, {
    subscriptionPlan: planType,
    subscriptionStatus: "ACTIVE",
    subscriptionExpiry: expiryTimestamp,
    lastUpgradeDate: admin.firestore.FieldValue.serverTimestamp(),
    purchasedAddons: updatedPurchased,
    addons: updatedAddons,
    entitlementVersion: currentVersion,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Canonical Server-Controlled Entitlement Document
  const entRef = storeRef.collection("entitlements").doc("current");
  batch.set(entRef, canonicalEntitlement, { merge: true });

  // 3. Append to Subscription History
  const historyRef = storeRef.collection("subscription_history").doc();
  batch.set(historyRef, {
    planName: planType,
    billingCycle,
    durationDays,
    startDate: admin.firestore.FieldValue.serverTimestamp(),
    endDate: expiryTimestamp,
    price,
    status: "ACTIVE",
    storeId,
    selectedAddons: updatedAddons,
    approvedBy: auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 4. Update Request if linked
  if (requestId) {
    const reqRef = db.collection("subscription_requests").doc(requestId);
    batch.update(reqRef, {
      status: "APPROVED",
      storeId,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: auth.uid,
    });
  }

  await batch.commit();

  return {
    success: true,
    storeId,
    plan: planType,
    status: "ACTIVE",
    expiry: expiryDate.toISOString(),
    entitlementVersion: currentVersion,
  };
});

/**
 * Server-authoritative plan changes (upgrade, downgrade, suspend, cancel).
 * Callable strictly by Super Admins.
 */
exports.changeSubscriptionPlan = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const db = admin.firestore();
  const callerIsAdmin = await isCallerSuperAdmin(auth, db);
  if (!callerIsAdmin) {
    throw new HttpsError("permission-denied", "Super Admin access required.");
  }

  const {
    storeId,
    newPlan,
    status = "ACTIVE",
    durationDays = 30,
    gracePeriodDays = 7,
    reason = "Admin plan adjustment",
  } = data || {};

  if (!storeId || !newPlan) {
    throw new HttpsError(
      "invalid-argument",
      "'storeId' and 'newPlan' are required."
    );
  }

  const storeRef = db.collection("stores").doc(storeId);
  const storeSnap = await storeRef.get();
  if (!storeSnap.exists) {
    throw new HttpsError("not-found", `Store '${storeId}' not found.`);
  }

  const storeData = storeSnap.data();
  const currentVersion = (storeData.entitlementVersion || 0) + 1;
  const now = new Date();
  const expiryDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

  const limits = DEFAULT_PLAN_LIMITS[newPlan] || DEFAULT_PLAN_LIMITS.Basic;
  const features = DEFAULT_PLAN_FEATURES[newPlan] || DEFAULT_PLAN_FEATURES.Basic;
  const purchasedAddons = storeData.purchasedAddons || [];
  const addons = storeData.addons || [];

  const tamperHash = computeEntitlementHash({
    storeId,
    plan: newPlan,
    status,
    version: currentVersion,
    addons,
    purchasedAddons,
    limits,
    features,
    endDate: expiryTimestamp,
    serverTimestamp: admin.firestore.Timestamp.fromDate(now),
  });

  const batch = db.batch();

  batch.update(storeRef, {
    subscriptionPlan: newPlan,
    subscriptionStatus: status,
    subscriptionExpiry: expiryTimestamp,
    entitlementVersion: currentVersion,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const entRef = storeRef.collection("entitlements").doc("current");
  batch.set(
    entRef,
    {
      storeId,
      plan: newPlan,
      status,
      endDate: expiryTimestamp,
      gracePeriodDays,
      addons,
      purchasedAddons,
      limits,
      features,
      version: currentVersion,
      tamperHash,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const histRef = storeRef.collection("subscription_history").doc();
  batch.set(histRef, {
    oldPlan: storeData.subscriptionPlan,
    newPlan,
    status,
    reason,
    changedBy: auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  return { success: true, storeId, plan: newPlan, status };
});

/**
 * Toggles an addon for a store.
 * Rejects if addon was not purchased (or included in plan).
 */
exports.purchaseOrToggleAddon = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { storeId, addonKey, enable = true, isPurchase = false } = data || {};
  if (!storeId || !addonKey) {
    throw new HttpsError(
      "invalid-argument",
      "'storeId' and 'addonKey' are required."
    );
  }

  const db = admin.firestore();
  const callerIsAdmin = await isCallerSuperAdmin(auth, db);

  // Check store membership if not super admin
  if (!callerIsAdmin) {
    const memberDoc = await db
      .collection("stores")
      .doc(storeId)
      .collection("members")
      .doc(auth.uid)
      .get();
    if (
      !memberDoc.exists ||
      (memberDoc.data().role !== "Owner" &&
        memberDoc.data().role !== "Store Owner" &&
        memberDoc.data().role !== "Manager")
    ) {
      throw new HttpsError(
        "permission-denied",
        "Only Store Owners or Managers can configure addons."
      );
    }
  }

  const storeRef = db.collection("stores").doc(storeId);
  const storeSnap = await storeRef.get();
  if (!storeSnap.exists) {
    throw new HttpsError("not-found", "Store not found.");
  }

  const storeData = storeSnap.data();
  const purchased = new Set(storeData.purchasedAddons || []);
  const active = new Set(storeData.addons || []);

  if (isPurchase) {
    // Only Super Admin can authorize purchase directly via this endpoint
    if (!callerIsAdmin) {
      throw new HttpsError(
        "permission-denied",
        "Addon purchase requires administrative approval or payment processing."
      );
    }
    purchased.add(addonKey);
    active.add(addonKey);
  } else {
    // Toggling: must already be purchased or included in enterprise
    const isEnterprise =
      (storeData.subscriptionPlan || "").toLowerCase() === "enterprise";
    if (!purchased.has(addonKey) && !isEnterprise && !callerIsAdmin) {
      throw new HttpsError(
        "failed-precondition",
        `Addon '${addonKey}' has not been purchased for this store.`
      );
    }

    if (enable) {
      active.add(addonKey);
    } else {
      active.delete(addonKey);
    }
  }

  await storeRef.update({
    addons: Array.from(active),
    purchasedAddons: Array.from(purchased),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    storeId,
    addonKey,
    enabled: active.has(addonKey),
    purchased: purchased.has(addonKey),
  };
});

/**
 * Server-authoritative quota enforcement check.
 * Validates store metrics against current subscription quotas.
 */
exports.enforceServerQuotas = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { storeId, action } = data || {};
  if (!storeId) {
    throw new HttpsError("invalid-argument", "'storeId' is required.");
  }

  const db = admin.firestore();
  const storeDoc = await db.collection("stores").doc(storeId).get();
  if (!storeDoc.exists) {
    throw new HttpsError("not-found", "Store not found.");
  }

  const storeData = storeDoc.data();
  const plan = storeData.subscriptionPlan || "Basic";
  const limits = DEFAULT_PLAN_LIMITS[plan] || DEFAULT_PLAN_LIMITS.Basic;

  const violations = [];

  // 1. Order Quota Evaluation
  if (action === "create_order" && limits.orders !== -1) {
    const ordersSnap = await db
      .collection("orders")
      .where("storeId", "==", storeId)
      .count()
      .get();
    const orderCount = ordersSnap.data().count;
    if (orderCount >= limits.orders) {
      violations.push(
        `Total orders (${orderCount}) exceeds plan limit (${limits.orders}).`
      );
    }
  }

  // 2. Inventory Quota Evaluation
  if (action === "add_inventory" && limits.inventory !== -1) {
    const invSnap = await db
      .collection("inventory")
      .where("storeId", "==", storeId)
      .count()
      .get();
    const invCount = invSnap.data().count;
    if (invCount >= limits.inventory) {
      violations.push(
        `Catalog items (${invCount}) exceeds plan limit (${limits.inventory}).`
      );
    }
  }

  // 3. Customer Quota Evaluation
  if (action === "add_customer" && limits.customers !== -1) {
    const custSnap = await db
      .collection("customers")
      .where("storeId", "==", storeId)
      .count()
      .get();
    const custCount = custSnap.data().count;
    if (custCount >= limits.customers) {
      violations.push(
        `Customers (${custCount}) exceeds plan limit (${limits.customers}).`
      );
    }
  }

  if (violations.length > 0) {
    throw new HttpsError(
      "resource-exhausted",
      violations.join(" ")
    );
  }

  return {
    allowed: true,
    storeId,
    plan,
    limits,
  };
});

// =============================================================================
// PRODUCTION HARDENING: TRANSACTIONAL POS & INVENTORY MUTATIONS
// =============================================================================

async function verifyStoreAccess(auth, db, storeId, allowedRoles = null) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const callerIsAdmin = await isCallerSuperAdmin(auth, db);
  if (callerIsAdmin) {
    return { isAdmin: true, role: "Super Admin" };
  }

  const memberDoc = await db
    .collection("stores")
    .doc(storeId)
    .collection("members")
    .doc(auth.uid)
    .get();

  if (!memberDoc.exists || memberDoc.data().status !== "ACTIVE") {
    const storeDoc = await db.collection("stores").doc(storeId).get();
    if (storeDoc.exists && storeDoc.data().owner === auth.uid) {
      return { isAdmin: false, role: "Owner" };
    }
    throw new HttpsError(
      "permission-denied",
      "User is not an active member of this store."
    );
  }

  const role = memberDoc.data().role;
  if (allowedRoles && Array.isArray(allowedRoles) && !allowedRoles.includes(role)) {
    throw new HttpsError(
      "permission-denied",
      `Action requires one of the following roles: ${allowedRoles.join(", ")}. Current role: ${role}`
    );
  }

  return { isAdmin: false, role };
}

/**
 * Atomic Server-Side Order Creation Transaction.
 * Validates cart totals, stock availability, and writes order, movements, and financial ledger atomically.
 */
exports.createOrderTransaction = onCall(async (request) => {
  const { data, auth } = request;
  const db = admin.firestore();

  const {
    orderId,
    storeId,
    items,
    subtotal,
    tax,
    discount,
    total,
    paymentMethod,
    paymentStatus,
    idempotencyKey,
  } = data || {};

  if (!storeId || !orderId || !items || !Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Missing required fields: storeId, orderId, and non-empty items array.");
  }

  // 1. Enforce store membership
  await verifyStoreAccess(auth, db, storeId);

  // 2. Check Idempotency Key
  const cleanIdempotencyKey = idempotencyKey || orderId;
  const existingOrderSnap = await db.collection("orders").doc(orderId).get();
  if (existingOrderSnap.exists) {
    return {
      success: true,
      orderId,
      duplicate: true,
      message: "Order already exists. Duplicate operation prevented.",
    };
  }

  const nowIso = new Date().toISOString();

  // 3. Execute Transaction
  const result = await db.runTransaction(async (transaction) => {
    const invRefs = [];
    const invSnaps = [];

    for (const item of items) {
      const iId = item.itemId || item.id;
      if (!iId) continue;
      const ref = db.collection("inventory").doc(iId);
      invRefs.push({ ref, item, itemId: iId });
    }

    for (const itemEntry of invRefs) {
      const snap = await transaction.get(itemEntry.ref);
      invSnaps.push({ ...itemEntry, snap });
    }

    const movements = [];
    for (const entry of invSnaps) {
      const requestedQty = Number(entry.item.quantity) || 1;
      let currentStock = 0;
      let trackStock = true;

      if (entry.snap.exists) {
        const invData = entry.snap.data();
        currentStock = Number(invData.quantity) || 0;
        trackStock = invData.trackStock !== false;

        if (trackStock && currentStock - requestedQty < 0) {
          throw new HttpsError(
            "failed-precondition",
            `Insufficient stock for item "${entry.item.name || entry.itemId}". Current stock: ${currentStock}, Requested: ${requestedQty}. Operation blocked to prevent negative inventory.`
          );
        }

        const newStock = trackStock ? currentStock - requestedQty : currentStock;
        transaction.update(entry.ref, {
          quantity: newStock,
          updatedAt: nowIso,
          updatedBy: auth.uid,
        });

        movements.push({
          id: `mov_sale_${orderId}_${entry.itemId}`,
          movementType: "SALE",
          storeId,
          itemId: entry.itemId,
          itemName: entry.item.name || "",
          quantity: requestedQty,
          previousStock: currentStock,
          newStock,
          orderId,
          createdAt: nowIso,
          createdBy: auth.uid,
        });
      }
    }

    for (const mov of movements) {
      const movRef = db.collection("inventory_movements").doc(mov.id);
      transaction.set(movRef, mov);
    }

    const ledgerRef = db.collection("financial_ledger").doc(`fin_sale_${orderId}`);
    transaction.set(ledgerRef, {
      id: `fin_sale_${orderId}`,
      storeId,
      orderId,
      entryType: "ORDER_SALE",
      amount: Number(total) || 0,
      subtotal: Number(subtotal) || 0,
      tax: Number(tax) || 0,
      discount: Number(discount) || 0,
      paymentMethod: paymentMethod || "Cash",
      paymentStatus: paymentStatus || "PAID",
      idempotencyKey: cleanIdempotencyKey,
      createdAt: nowIso,
      createdBy: auth.uid,
    });

    const orderRef = db.collection("orders").doc(orderId);
    transaction.set(orderRef, {
      ...data,
      id: orderId,
      storeId,
      status: data.status || "Completed",
      createdAt: nowIso,
      updatedAt: nowIso,
      createdBy: auth.uid,
      idempotencyKey: cleanIdempotencyKey,
      syncedAt: nowIso,
      version: 1,
    });

    const logRef = db.collection("activity_logs").doc(`log_${orderId}`);
    transaction.set(logRef, {
      storeId,
      action: "ORDER_CREATED",
      targetId: orderId,
      userId: auth.uid,
      details: `Created order #${orderId} with ${items.length} items. Total: ₹${total}`,
      timestamp: nowIso,
    });

    return { orderId, total, itemsCount: items.length };
  });

  return {
    success: true,
    ...result,
    message: "Order placed and inventory stock atomically reconciled.",
  };
});

/**
 * Atomic Server-Side Refund or Void Processing.
 * Restores inventory stock, marks order as refunded/void, and writes reversing ledger entry.
 */
exports.processRefundVoid = onCall(async (request) => {
  const { data, auth } = request;
  const db = admin.firestore();

  const { storeId, orderId, action, reason, refundItems } = data || {};
  if (!storeId || !orderId || !action || !["REFUND", "VOID"].includes(action)) {
    throw new HttpsError("invalid-argument", "Missing required fields: storeId, orderId, and action ('REFUND' or 'VOID').");
  }

  await verifyStoreAccess(auth, db, storeId, ["Owner", "Store Owner", "Manager", "Super Admin"]);
  const nowIso = new Date().toISOString();

  const result = await db.runTransaction(async (transaction) => {
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await transaction.get(orderRef);

    if (!orderSnap.exists) {
      throw new HttpsError("not-found", `Order #${orderId} not found.`);
    }

    const orderData = orderSnap.data();
    if (orderData.storeId !== storeId) {
      throw new HttpsError("permission-denied", "Cross-store mutation prohibited.");
    }

    if (orderData.status === "VOID" || orderData.status === "Refunded") {
      throw new HttpsError("failed-precondition", `Order #${orderId} is already ${orderData.status.toLowerCase()}.`);
    }

    const itemsToRestore = refundItems && Array.isArray(refundItems) && refundItems.length > 0
      ? refundItems
      : (orderData.items || []);

    for (const item of itemsToRestore) {
      const itemId = item.itemId || item.id;
      if (!itemId) continue;

      const invRef = db.collection("inventory").doc(itemId);
      const invSnap = await transaction.get(invRef);

      if (invSnap.exists) {
        const invData = invSnap.data();
        const currentStock = Number(invData.quantity) || 0;
        const restoredQty = Number(item.quantity) || 1;
        const newStock = currentStock + restoredQty;

        transaction.update(invRef, {
          quantity: newStock,
          updatedAt: nowIso,
          updatedBy: auth.uid,
        });

        const movId = `mov_${action.toLowerCase()}_${orderId}_${itemId}_${Date.now()}`;
        const movRef = db.collection("inventory_movements").doc(movId);
        transaction.set(movRef, {
          id: movId,
          movementType: action === "VOID" ? "VOID_REVERSAL" : "REFUND",
          storeId,
          itemId,
          itemName: item.name || "",
          quantity: restoredQty,
          previousStock: currentStock,
          newStock,
          orderId,
          reason: reason || "Customer Return",
          createdAt: nowIso,
          createdBy: auth.uid,
        });
      }
    }

    const refundAmount = action === "VOID" ? orderData.total : (data.amount || orderData.total);
    const ledgerId = `fin_${action.toLowerCase()}_${orderId}_${Date.now()}`;
    const ledgerRef = db.collection("financial_ledger").doc(ledgerId);
    transaction.set(ledgerRef, {
      id: ledgerId,
      storeId,
      orderId,
      entryType: action === "VOID" ? "ORDER_VOID" : "ORDER_REFUND",
      amount: -Math.abs(Number(refundAmount) || 0),
      reason: reason || "",
      createdAt: nowIso,
      createdBy: auth.uid,
    });

    const newStatus = action === "VOID" ? "VOID" : "Refunded";
    transaction.update(orderRef, {
      status: newStatus,
      updatedAt: nowIso,
      updatedBy: auth.uid,
      cancellationReason: reason || "",
    });

    const logRef = db.collection("activity_logs").doc(`log_${ledgerId}`);
    transaction.set(logRef, {
      storeId,
      action: `ORDER_${action}`,
      targetId: orderId,
      userId: auth.uid,
      details: `${action} processed for order #${orderId}. Reversal amount: ₹${refundAmount}. Reason: ${reason || 'None'}`,
      timestamp: nowIso,
    });

    return { orderId, status: newStatus, reversedAmount: refundAmount };
  });

  return { success: true, ...result };
});

/**
 * Atomic Server-Side Stock Adjustment.
 */
exports.adjustInventoryStock = onCall(async (request) => {
  const { data, auth } = request;
  const db = admin.firestore();

  const { storeId, itemId, delta, reason, notes } = data || {};
  if (!storeId || !itemId || delta === undefined || delta === null) {
    throw new HttpsError("invalid-argument", "Missing required fields: storeId, itemId, and delta.");
  }

  await verifyStoreAccess(auth, db, storeId, ["Owner", "Store Owner", "Manager", "Super Admin"]);
  const nowIso = new Date().toISOString();
  const numDelta = Number(delta);

  const result = await db.runTransaction(async (transaction) => {
    const invRef = db.collection("inventory").doc(itemId);
    const invSnap = await transaction.get(invRef);

    if (!invSnap.exists) {
      throw new HttpsError("not-found", `Item #${itemId} not found.`);
    }

    const invData = invSnap.data();
    if (invData.storeId && invData.storeId !== storeId) {
      throw new HttpsError("permission-denied", "Cross-store inventory adjustment prohibited.");
    }

    const currentStock = Number(invData.quantity) || 0;
    const newStock = currentStock + numDelta;

    if (newStock < 0) {
      throw new HttpsError(
        "failed-precondition",
        `Adjustment would result in negative stock (${newStock}). Current: ${currentStock}, Delta: ${numDelta}. Operation blocked.`
      );
    }

    transaction.update(invRef, {
      quantity: newStock,
      updatedAt: nowIso,
      updatedBy: auth.uid,
    });

    const movId = `mov_adj_${itemId}_${Date.now()}`;
    const movRef = db.collection("inventory_movements").doc(movId);
    transaction.set(movRef, {
      id: movId,
      movementType: reason || (numDelta >= 0 ? "SURPLUS" : "DAMAGE"),
      storeId,
      itemId,
      itemName: invData.name || "",
      quantity: Math.abs(numDelta),
      previousStock: currentStock,
      newStock,
      notes: notes || "",
      createdAt: nowIso,
      createdBy: auth.uid,
    });

    const logRef = db.collection("activity_logs").doc(`log_${movId}`);
    transaction.set(logRef, {
      storeId,
      action: "STOCK_ADJUSTMENT",
      targetId: itemId,
      userId: auth.uid,
      details: `Adjusted stock for ${invData.name || itemId} by ${numDelta} (${reason || 'MANUAL'}). New stock: ${newStock}`,
      timestamp: nowIso,
    });

    return { itemId, previousStock: currentStock, newStock };
  });

  return { success: true, ...result };
});

/**
 * Atomic Server-Side Payment Status Update.
 */
exports.updatePaymentStatus = onCall(async (request) => {
  const { data, auth } = request;
  const db = admin.firestore();

  const { storeId, orderId, paymentStatus, paymentMethod, transactionReference } = data || {};
  if (!storeId || !orderId || !paymentStatus) {
    throw new HttpsError("invalid-argument", "Missing required fields: storeId, orderId, and paymentStatus.");
  }

  await verifyStoreAccess(auth, db, storeId);
  const nowIso = new Date().toISOString();

  const result = await db.runTransaction(async (transaction) => {
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await transaction.get(orderRef);

    if (!orderSnap.exists) {
      throw new HttpsError("not-found", `Order #${orderId} not found.`);
    }

    const orderData = orderSnap.data();
    if (orderData.storeId !== storeId) {
      throw new HttpsError("permission-denied", "Cross-store order update prohibited.");
    }

    transaction.update(orderRef, {
      paymentStatus,
      paymentMethod: paymentMethod || orderData.paymentMethod,
      transactionReference: transactionReference || orderData.transactionReference || "",
      updatedAt: nowIso,
      updatedBy: auth.uid,
    });

    const ledgerId = `fin_pay_${orderId}_${Date.now()}`;
    const ledgerRef = db.collection("financial_ledger").doc(ledgerId);
    transaction.set(ledgerRef, {
      id: ledgerId,
      storeId,
      orderId,
      entryType: "PAYMENT_STATUS_UPDATE",
      paymentStatus,
      paymentMethod: paymentMethod || orderData.paymentMethod,
      amount: orderData.total || 0,
      createdAt: nowIso,
      createdBy: auth.uid,
    });

    return { orderId, paymentStatus };
  });

  return { success: true, ...result };
});


