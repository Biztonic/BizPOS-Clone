const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const app = initializeApp({ projectId: 'bizpos-clone' });
const db = getFirestore(app);
const auth = getAuth(app);

const COLLECTIONS = [
  'addon_reviews',
  'business_events',
  'floors',
  'inventory',
  'inventory_movements',
  'orders',
  'settings',
  'stores',
  'subscription_requests',
  'tables',
  'users',
];

async function deleteCollection(collectionPath) {
  const batchSize = 100;
  const collectionRef = db.collection(collectionPath);
  let deleted = 0;

  while (true) {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;
    console.log(`  Deleted ${deleted} docs from ${collectionPath}...`);
  }

  console.log(`✅ ${collectionPath}: ${deleted} documents deleted`);
  return deleted;
}

async function deleteAllAuthUsers() {
  console.log('\n--- Deleting Auth Users ---');
  let deleted = 0;
  const listResult = await auth.listUsers(1000);
  const uids = listResult.users.map(u => u.uid);

  if (uids.length === 0) {
    console.log('No auth users found.');
    return 0;
  }

  console.log(`Found ${uids.length} auth user(s)`);
  const result = await auth.deleteUsers(uids);
  deleted = result.successCount;
  console.log(`✅ Deleted ${deleted} auth user(s)`);
  if (result.failureCount > 0) {
    console.log(`⚠️ Failed to delete ${result.failureCount} user(s):`);
    result.errors.forEach(e => console.log(`  - ${e.error.message}`));
  }
  return deleted;
}

async function main() {
  console.log('🔥 Firebase Full Cleanup - bizpos-clone\n');
  console.log('--- Deleting Firestore Collections ---');

  let totalDocs = 0;
  for (const col of COLLECTIONS) {
    try {
      totalDocs += await deleteCollection(col);
    } catch (err) {
      console.log(`❌ Error deleting ${col}: ${err.message}`);
    }
  }

  console.log(`\nFirestore: ${totalDocs} total documents deleted`);

  try {
    await deleteAllAuthUsers();
  } catch (err) {
    console.log(`❌ Error deleting auth users: ${err.message}`);
  }

  console.log('\n🎉 Cleanup complete! Database reset to zero.');
}

main().catch(console.error);
