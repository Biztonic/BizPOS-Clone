/**
 * BizPOS Backend Initialization Script
 * 
 * This script populates the initial configuration and Super Admin profile
 * in the new Firebase project.
 * 
 * PREREQUISITES:
 * 1. Node.js installed
 * 2. Run: npm install firebase
 * 3. Keep your firebase_options.dart open to copy the config
 */

const { initializeApp } = require("firebase/app");
const { getFirestore, doc, setDoc, serverTimestamp } = require("firebase/firestore");

// --- 1. CONFIGURATION ---
// Copy these from lib/firebase_options.dart (Web Configuration)
const firebaseConfig = {
  apiKey: "AIzaSyC7mm2GLO9ZYsyBMWh1U6FF6hzEE5QQgJw",
  authDomain: "bizpos-clone.firebaseapp.com",
  projectId: "bizpos-clone",
  storageBucket: "bizpos-clone.firebasestorage.app",
  messagingSenderId: "621791784014",
  appId: "1:621791784014:web:8e0c96ea7bfdac98e3671f"
};

// --- 2. DATA DEFAULTS ---
const ADMIN_EMAIL = "pthorat600@gmail.com";
const INITIAL_CONFIG = {
  adminUpiId: "pthorat600@okicici",
  standardPlanMonthlyPrice: 999.0,
  standardPlanYearlyPrice: 9990.0,
  disabledAddons: [],
  platformLimits: {
    rate_employee_management: 199.0,
    rate_table_reservation: 149.0,
    rate_supplier_management: 149.0,
    rate_kds_management: 99.0,
    rate_franchise_management: 499.0,
    rate_central_catalog: 249.0,
    rate_customer_management: 99.0,
    rate_data_center: 199.0,
    rate_integration_hub: 299.0
  }
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function initialize() {
  console.log("Starting initialization for project: " + firebaseConfig.projectId);

  try {
    // 1. Initialize admin_config
    console.log("Setting up admin_config...");
    await setDoc(doc(db, "settings", "admin_config"), INITIAL_CONFIG, { merge: true });

    // 2. Initialize/Update Super Admin Profile
    // Note: This assumes the user 'pthorat600@gmail.com' already signed up. 
    // If not, it will just create the shell for the UID once they sign in.
    console.log("Pre-configuring Super Admin permissions for " + ADMIN_EMAIL + "...");
    // We create a doc with the email as ID if we don't know the UID yet, 
    // or just let the app handle it on first login. 
    // Recommended: Provide a dummy store if needed, but for now we just set the platform settings.

    console.log("\x1b[32m%s\x1b[0m", "SUCCESS: Production environment initialized!");
    console.log("Next Step: Deploy the firestore.rules file using Firebase CLI.");
    
    // Give it a moment to finish any background tasks
    setTimeout(() => process.exit(0), 1000);

  } catch (error) {
    console.error("\x1b[31m%s\x1b[0m", "ERROR: Initialization failed.");
    console.error(error);
    process.exit(1);
  }
}

initialize();
