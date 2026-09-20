const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");
const path = require("path");
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert");

const PROJECT_ID = "bizpos-tenant-isolation-test";
let testEnv;

before(async () => {
  const rulesPath = path.resolve(__dirname, "../../firestore.rules");
  const rules = fs.readFileSync(rulesPath, "utf8");

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8085,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  // Seed baseline tenant data
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Store A
    await db.collection("stores").doc("storeA").set({
      name: "Store A",
      owner: "ownerA",
      subscriptionPlan: "Basic",
      subscriptionStatus: "ACTIVE",
      addons: [],
    });
    // Active Owner in Store A
    await db.collection("stores").doc("storeA").collection("members").doc("ownerA").set({
      uid: "ownerA",
      storeId: "storeA",
      role: "Owner",
      status: "ACTIVE",
    });
    // Active member in Store A
    await db.collection("stores").doc("storeA").collection("members").doc("userA").set({
      uid: "userA",
      storeId: "storeA",
      role: "Cashier",
      status: "ACTIVE",
    });
    // Employee in Store A
    await db.collection("stores").doc("storeA").collection("members").doc("empA").set({
      uid: "empA",
      storeId: "storeA",
      role: "Staff",
      status: "ACTIVE",
    });
    // Manager in Store A
    await db.collection("stores").doc("storeA").collection("members").doc("managerA").set({
      uid: "managerA",
      storeId: "storeA",
      role: "Manager",
      status: "ACTIVE",
    });
    // Removed member in Store A
    await db.collection("stores").doc("storeA").collection("members").doc("removedUser").set({
      uid: "removedUser",
      storeId: "storeA",
      role: "Cashier",
      status: "REMOVED",
    });

    // Store B
    await db.collection("stores").doc("storeB").set({
      name: "Store B",
      owner: "ownerB",
    });
    // Active member in Store B
    await db.collection("stores").doc("storeB").collection("members").doc("userB").set({
      uid: "userB",
      storeId: "storeB",
      role: "Cashier",
      status: "ACTIVE",
    });

    // Orders
    await db.collection("orders").doc("orderA1").set({
      storeId: "storeA",
      total: 100,
    });
    await db.collection("orders").doc("orderB1").set({
      storeId: "storeB",
      total: 200,
    });
    // Finalized Order in Store A
    await db.collection("orders").doc("finalizedOrderA").set({
      storeId: "storeA",
      total: 100,
      subtotal: 90,
      status: "Completed",
      items: [{ id: "item1", qty: 1 }],
    });

    // Inventory Movements
    await db.collection("inventory_movements").doc("mvt1").set({
      storeId: "storeA",
      itemId: "item1",
      delta: 1,
    });

    // Activity Logs
    await db.collection("activity_logs").doc("log1").set({
      storeId: "storeA",
      action: "LOGIN",
    });

    // Users
    await db.collection("users").doc("userA").set({
      email: "userA@biztonic.pos",
      name: "User A",
      role: "Cashier",
      storeId: "storeA",
      accessibleStoreIds: ["storeA"],
    });

    // Platform Admins
    await db.collection("platform_admins").doc("superAdminUid").set({
      uid: "superAdminUid",
      status: "ACTIVE",
    });

    // Global Settings
    await db.collection("settings").doc("admin_config").set({
      maintenanceMode: false,
    });
  });
});

test("1. Store A user reads Store A order -> ALLOW", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const orderRef = userAContext.firestore().collection("orders").doc("orderA1");
  await assertSucceeds(orderRef.get());
});

test("2. Store A user reads Store B order -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const orderRef = userAContext.firestore().collection("orders").doc("orderB1");
  await assertFails(orderRef.get());
});

test("3. Store A user writes Store B order -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const orderRef = userAContext.firestore().collection("orders").doc("orderB2");
  await assertFails(orderRef.set({ storeId: "storeB", total: 50 }));
});

test("4. Store A user changes own role to Super Admin -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const userDocRef = userAContext.firestore().collection("users").doc("userA");
  await assertFails(userDocRef.update({ role: "Super Admin" }));
});

test("5. Store A user adds Store B to accessibleStoreIds -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const userDocRef = userAContext.firestore().collection("users").doc("userA");
  await assertFails(userDocRef.update({ accessibleStoreIds: ["storeA", "storeB"] }));
});

test("6. New normal user creates privileged profile -> DENY", async () => {
  const newNormalUserContext = testEnv.authenticatedContext("newUser1");
  const privilegedRef = newNormalUserContext.firestore().collection("users").doc("newUser1");
  await assertFails(privilegedRef.set({ email: "new@bizpos.com", role: "Super Admin" }));
  await assertSucceeds(privilegedRef.set({ email: "new@bizpos.com", role: "Cashier" }));
});

test("7. Anonymous user accesses private store data -> DENY", async () => {
  const anonContext = testEnv.authenticatedContext("anonUser", {
    provider_id: "anonymous",
    firebase: { sign_in_provider: "anonymous" },
  });
  await assertFails(anonContext.firestore().collection("orders").doc("orderA1").get());
  await assertFails(anonContext.firestore().collection("stores").doc("storeA").get());
});

test("8. Employee from Store A accesses Store B -> DENY", async () => {
  const empAContext = testEnv.authenticatedContext("empA");
  await assertFails(empAContext.firestore().collection("orders").doc("orderB1").get());
  await assertFails(empAContext.firestore().collection("stores").doc("storeB").get());
});

test("9. Super Admin accesses authorized global configuration -> ALLOW", async () => {
  const adminContext = testEnv.authenticatedContext("superAdminUid", {
    role: "super_admin",
    isSuperAdmin: true,
  });
  await assertSucceeds(adminContext.firestore().collection("settings").doc("admin_config").get());
  await assertSucceeds(adminContext.firestore().collection("orders").doc("orderA1").get());
  await assertSucceeds(adminContext.firestore().collection("orders").doc("orderB1").get());
});

test("10. Removed membership accesses store -> DENY", async () => {
  const removedUserContext = testEnv.authenticatedContext("removedUser");
  await assertFails(removedUserContext.firestore().collection("orders").doc("orderA1").get());
  await assertFails(removedUserContext.firestore().collection("stores").doc("storeA").get());
});

test("11. Malicious payload: Store Owner attempts to arbitrarily elevate subscriptionPlan to Enterprise -> DENY", async () => {
  const ownerAContext = testEnv.authenticatedContext("ownerA");
  const storeRef = ownerAContext.firestore().collection("stores").doc("storeA");
  await assertFails(storeRef.update({ subscriptionPlan: "Enterprise" }));
});

test("12. Malicious payload: Store Owner attempts to inject unauthorized addons -> DENY", async () => {
  const ownerAContext = testEnv.authenticatedContext("ownerA");
  const storeRef = ownerAContext.firestore().collection("stores").doc("storeA");
  await assertFails(storeRef.update({ addons: ["crm", "kds", "multi_store"] }));
});

test("13. Malicious payload: Client attempts to directly write to platform_admins collection -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const adminDoc = userAContext.firestore().collection("platform_admins").doc("userA");
  await assertFails(adminDoc.set({ uid: "userA", status: "ACTIVE" }));
});

test("14. Malicious payload: Normal user attempts to modify global settings/admin_config -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const configDoc = userAContext.firestore().collection("settings").doc("admin_config");
  await assertFails(configDoc.update({ maintenanceMode: true }));
});

test("15. Unauthenticated user reads /users/{uid} -> DENY", async () => {
  const unauthContext = testEnv.unauthenticatedContext();
  const userRef = unauthContext.firestore().collection("users").doc("userA");
  await assertFails(userRef.get());
});

test("16. Non-super-admin user writes to central_catalog -> DENY; Super Admin writes -> ALLOW", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const catalogRef = userAContext.firestore().collection("central_catalog").doc("item1");
  await assertFails(catalogRef.set({ name: "Hacked Item", price: 10 }));

  const adminContext = testEnv.authenticatedContext("superAdminUid", {
    role: "super_admin",
    isSuperAdmin: true,
  });
  const adminCatalogRef = adminContext.firestore().collection("central_catalog").doc("item1");
  await assertSucceeds(adminCatalogRef.set({ name: "Official Item", price: 10 }));
});

test("17. Public leads: Valid lead payload -> ALLOW; Malformed lead payload -> DENY", async () => {
  const unauthContext = testEnv.unauthenticatedContext();
  const leadsCol = unauthContext.firestore().collection("leads");

  // Valid lead
  await assertSucceeds(leadsCol.doc("lead1").set({
    name: "John Doe",
    phone: "1234567890",
    email: "john@example.com",
    storeName: "John's Bakery",
    source: "landing_page",
  }));

  // Malformed lead: missing required 'phone'
  await assertFails(leadsCol.doc("lead2").set({
    name: "John Doe",
    email: "john@example.com",
  }));

  // Malformed lead: unauthorized extra keys
  await assertFails(leadsCol.doc("lead3").set({
    name: "John Doe",
    phone: "1234567890",
    isAdmin: true,
  }));
});

test("18. Store member updates finalized order total or items -> DENY", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const orderRef = userAContext.firestore().collection("orders").doc("finalizedOrderA");
  // Attempting to change total of completed order
  await assertFails(orderRef.update({ total: 10 }));
  // Attempting to change items of completed order
  await assertFails(orderRef.update({ items: [] }));
});

test("19. Direct update to inventory_movements -> DENY (Append-only ledger)", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const mvtRef = userAContext.firestore().collection("inventory_movements").doc("mvt1");
  await assertFails(mvtRef.update({ delta: 999 }));
});

test("20. Direct update or delete to activity_logs -> DENY (Append-only audit trail)", async () => {
  const userAContext = testEnv.authenticatedContext("userA");
  const logRef = userAContext.firestore().collection("activity_logs").doc("log1");
  await assertFails(logRef.update({ action: "TAMPERED" }));
  await assertFails(logRef.delete());
});

test("21. Manager attempts to promote member to Owner -> DENY", async () => {
  const managerContext = testEnv.authenticatedContext("managerA");
  const memberRef = managerContext.firestore().collection("stores").doc("storeA").collection("members").doc("userA");
  await assertFails(memberRef.update({ role: "Owner" }));
  await assertFails(memberRef.update({ role: "Store Owner" }));
});

