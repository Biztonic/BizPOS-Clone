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
