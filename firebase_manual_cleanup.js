/**
 * Firebase Cloud Functions Script for Backend Cleanup
 * 
 * INSTRUCTIONS:
 * 1. Go to Firebase Console → Firestore → Rules
 * 2. Temporarily set rules to allow admin access:
 *    rules_version = '2';
 *    service cloud.firestore {
 *      match /databases/{database}/documents {
 *        match /{document=**} {
 *          allow read, write: if true;
 *        }
 *      }
 *    }
 * 3. Open browser console (F12) on any Firebase Console page
 * 4. Copy and paste this entire script
 * 5. Run: await cleanupBackend(['d65d816a-338a-46ee-b102-1066c2d1329e', '7htlU4GbAOztGJHqkheR'])
 *    (Replace IDs with stores you want to KEEP)
 * 6. Restore your original Firestore rules after cleanup
 */

async function cleanupBackend(storeIdsToKeep = []) {
    console.log('=== FIREBASE BACKEND CLEANUP ===');
    console.log('Stores to KEEP:', storeIdsToKeep);

    // Initialize Firestore (should already be available in Firebase Console)
    const db = firebase.firestore();

    try {
        // 1. Get ALL stores
        console.log('\n--- Fetching all stores ---');
        const storesSnap = await db.collection('stores').get();
        console.log(`Found ${storesSnap.docs.length} total stores`);

        const storesToDelete = [];
        const storesToKeep = [];

        storesSnap.docs.forEach(doc => {
            const storeId = doc.id;
            const data = doc.data();
            const storeName = data?.name || 'Unknown';

            if (storeIdsToKeep.includes(storeId)) {
                storesToKeep.push({ id: storeId, name: storeName });
            } else {
                storesToDelete.push({ id: storeId, name: storeName });
            }
        });

        console.log(`\nStores to KEEP (${storesToKeep.length}):`);
        storesToKeep.forEach(s => console.log(`  ✓ ${s.name} (${s.id})`));

        console.log(`\nStores to DELETE (${storesToDelete.length}):`);
        storesToDelete.forEach(s => console.log(`  ✗ ${s.name} (${s.id})`));

        if (storesToDelete.length === 0) {
            console.log('\n✅ No stores to delete!');
            return;
        }

        // Confirm
        const confirm = window.confirm(
            `This will DELETE ${storesToDelete.length} stores and ALL their data!\n\n` +
            `Stores to DELETE:\n${storesToDelete.map(s => `- ${s.name}`).join('\n')}\n\n` +
            `Stores to KEEP:\n${storesToKeep.map(s => `- ${s.name}`).join('\n')}\n\n` +
            `This CANNOT be undone! Continue?`
        );

        if (!confirm) {
            console.log('❌ Cleanup cancelled by user');
            return;
        }

        // 2. Delete data for each store
        const collections = ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes'];

        for (const store of storesToDelete) {
            console.log(`\n--- Deleting store: ${store.name} (${store.id}) ---`);

            // Delete all data for this store
            for (const collectionName of collections) {
                const snap = await db.collection(collectionName)
                    .where('storeId', '==', store.id)
                    .get();

                if (snap.docs.length > 0) {
                    console.log(`  Deleting ${snap.docs.length} docs from ${collectionName}...`);

                    // Delete in batches of 500
                    const batchSize = 500;
                    for (let i = 0; i < snap.docs.length; i += batchSize) {
                        const batch = db.batch();
                        const batchDocs = snap.docs.slice(i, i + batchSize);
                        batchDocs.forEach(doc => batch.delete(doc.ref));
                        await batch.commit();
                    }
                }
            }

            // Delete the store document itself
            await db.collection('stores').doc(store.id).delete();
            console.log(`  ✅ Store deleted`);
        }

        console.log('\n=== CLEANUP COMPLETE ===');
        console.log(`✅ Deleted ${storesToDelete.length} stores`);
        console.log(`✅ Kept ${storesToKeep.length} stores`);

        // Verify
        const finalStoresSnap = await db.collection('stores').get();
        console.log(`\nFinal store count: ${finalStoresSnap.docs.length}`);

    } catch (error) {
        console.error('❌ ERROR during cleanup:', error);
        throw error;
    }
}

// Helper function to list all stores first
async function listAllStores() {
    const db = firebase.firestore();
    const storesSnap = await db.collection('stores').get();

    console.log(`\n=== ALL STORES (${storesSnap.docs.length}) ===`);

    for (const doc of storesSnap.docs) {
        const data = doc.data();
        console.log(`\nStore ID: ${doc.id}`);
        console.log(`  Name: ${data?.name || 'Unknown'}`);
        console.log(`  Owner: ${data?.ownerEmail || data?.owner || 'Unknown'}`);
        console.log(`  Status: ${data?.status || 'Unknown'}`);

        // Count data
        const collections = ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables'];
        for (const col of collections) {
            const snap = await db.collection(col).where('storeId', '==', doc.id).get();
            if (snap.docs.length > 0) {
                console.log(`  ${col}: ${snap.docs.length} docs`);
            }
        }
    }
}

console.log('✅ Cleanup script loaded!');
console.log('\nUsage:');
console.log('1. First, list all stores:');
console.log('   await listAllStores()');
console.log('\n2. Then, cleanup (specify stores to KEEP):');
console.log('   await cleanupBackend(["store-id-1", "store-id-2"])');
console.log('\nExample:');
console.log('   await cleanupBackend(["d65d816a-338a-46ee-b102-1066c2d1329e", "7htlU4GbAOztGJHqkheR"])');
