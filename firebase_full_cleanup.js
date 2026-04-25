/**
 * Firebase Full Backend Cleanup Script
 * 
 * PURPOSE: Delete ALL data from Firestore EXCEPT the super admin user (pthorat600@gmail.com).
 * 
 * INSTRUCTIONS:
 * 1. Go to Firebase Console → Firestore → Rules
 * 2. Temporarily set rules to allow full access:
 *    rules_version = '2';
 *    service cloud.firestore {
 *      match /databases/{database}/documents {
 *        match /{document=**} {
 *          allow read, write: if true;
 *        }
 *      }
 *    }
 * 3. Go to Firebase Console → Firestore Database page
 * 4. Open browser console (F12 → Console tab)
 * 5. Copy and paste this entire script, then press Enter
 * 6. Run: await fullCleanup()
 * 7. RESTORE your original Firestore rules after cleanup!
 * 
 * ALSO: Go to Firebase Console → Authentication → Users
 *        Delete ALL users EXCEPT pthorat600@gmail.com manually.
 */

async function deleteCollection(db, collectionName, filter) {
    console.log(`  📦 Cleaning collection: ${collectionName}...`);
    let query = db.collection(collectionName);
    
    let totalDeleted = 0;
    let hasMore = true;
    
    while (hasMore) {
        const snap = await query.limit(400).get();
        
        if (snap.docs.length === 0) {
            hasMore = false;
            break;
        }
        
        const batch = db.batch();
        let batchCount = 0;
        
        for (const doc of snap.docs) {
            if (filter && !filter(doc)) continue; // Skip if filter says keep
            batch.delete(doc.ref);
            batchCount++;
        }
        
        if (batchCount > 0) {
            await batch.commit();
            totalDeleted += batchCount;
        }
        
        // If we got fewer docs than the limit, we're done
        if (snap.docs.length < 400) {
            hasMore = false;
        }
    }
    
    if (totalDeleted > 0) {
        console.log(`     ✅ Deleted ${totalDeleted} docs from ${collectionName}`);
    } else {
        console.log(`     ⏭️  ${collectionName}: empty or nothing to delete`);
    }
    return totalDeleted;
}

async function deleteSubcollections(db, parentCollection, subcollections) {
    console.log(`  📂 Cleaning subcollections of ${parentCollection}...`);
    const parentSnap = await db.collection(parentCollection).get();
    
    for (const parentDoc of parentSnap.docs) {
        for (const subCol of subcollections) {
            const subSnap = await parentDoc.ref.collection(subCol).get();
            if (subSnap.docs.length > 0) {
                const batch = db.batch();
                subSnap.docs.forEach(doc => batch.delete(doc.ref));
                await batch.commit();
                console.log(`     ✅ Deleted ${subSnap.docs.length} docs from ${parentCollection}/${parentDoc.id}/${subCol}`);
            }
        }
    }
}

async function fullCleanup() {
    const SUPER_ADMIN_EMAIL = 'pthorat600@gmail.com';
    
    console.log('╔══════════════════════════════════════════════╗');
    console.log('║     FULL FIREBASE BACKEND CLEANUP            ║');
    console.log('║     Keeping ONLY: ' + SUPER_ADMIN_EMAIL + '  ║');
    console.log('╚══════════════════════════════════════════════╝');
    
    const db = firebase.firestore();
    
    // Confirm
    const confirm = window.confirm(
        'WARNING: This will DELETE ALL DATA from Firestore!\n\n' +
        'Only the super admin user profile (pthorat600@gmail.com) will be preserved.\n\n' +
        'Collections to be cleaned:\n' +
        '- stores (and subcollections: floors, tables, counters)\n' +
        '- users (except super admin)\n' +
        '- orders\n' +
        '- inventory\n' +
        '- customers\n' +
        '- employees\n' +
        '- suppliers\n' +
        '- subscription_requests\n' +
        '- subscription_history\n' +
        '- addon_reviews\n' +
        '- activity_logs\n' +
        '- roles (except system roles)\n' +
        '- notes\n' +
        '- business_events\n\n' +
        'This CANNOT be undone! Continue?'
    );
    
    if (!confirm) {
        console.log('❌ Cleanup cancelled.');
        return;
    }
    
    let totalDeleted = 0;
    const startTime = Date.now();
    
    try {
        // 1. Delete store subcollections first
        console.log('\n--- STEP 1: Store subcollections ---');
        await deleteSubcollections(db, 'stores', ['floors', 'tables', 'counters', 'settings']);
        
        // 2. Delete all top-level data collections
        console.log('\n--- STEP 2: Top-level data collections ---');
        
        const dataCollections = [
            'orders',
            'inventory', 
            'customers',
            'employees',
            'suppliers',
            'notes',
            'activity_logs',
            'business_events',
            'addon_reviews',
            'subscription_requests',
            'subscription_history',
        ];
        
        for (const col of dataCollections) {
            totalDeleted += await deleteCollection(db, col);
        }
        
        // 3. Delete stores
        console.log('\n--- STEP 3: Stores ---');
        totalDeleted += await deleteCollection(db, 'stores');
        
        // 4. Delete users EXCEPT super admin
        console.log('\n--- STEP 4: Users (keeping super admin) ---');
        totalDeleted += await deleteCollection(db, 'users', (doc) => {
            const data = doc.data();
            const email = data?.email || '';
            if (email === SUPER_ADMIN_EMAIL) {
                console.log(`     🛡️  KEEPING super admin: ${email} (${doc.id})`);
                return false; // Don't delete
            }
            return true; // Delete
        });
        
        // 5. Clean roles (keep system roles)
        console.log('\n--- STEP 5: Custom roles ---');
        totalDeleted += await deleteCollection(db, 'roles', (doc) => {
            const data = doc.data();
            if (data?.isSystem === true) {
                console.log(`     🛡️  KEEPING system role: ${data.name}`);
                return false;
            }
            return true;
        });
        
        // 6. Settings cleanup (keep admin_config and platform_limits, app_version)
        console.log('\n--- STEP 6: Settings (keeping admin config) ---');
        const settingsToKeep = ['admin_config', 'platform_limits', 'app_version', 'global'];
        totalDeleted += await deleteCollection(db, 'settings', (doc) => {
            if (settingsToKeep.includes(doc.id)) {
                console.log(`     🛡️  KEEPING settings/${doc.id}`);
                return false;
            }
            return true;
        });
        
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        
        console.log('\n╔══════════════════════════════════════════════╗');
        console.log(`║  ✅ CLEANUP COMPLETE                          ║`);
        console.log(`║  Total documents deleted: ${totalDeleted}                ║`);
        console.log(`║  Time elapsed: ${elapsed}s                        ║`);
        console.log('╚══════════════════════════════════════════════╝');
        
        // Verify
        console.log('\n--- Verification ---');
        const usersSnap = await db.collection('users').get();
        console.log(`Users remaining: ${usersSnap.docs.length}`);
        usersSnap.docs.forEach(d => console.log(`  - ${d.data()?.email || d.id}`));
        
        const storesSnap = await db.collection('stores').get();
        console.log(`Stores remaining: ${storesSnap.docs.length}`);
        
    } catch (error) {
        console.error('❌ ERROR during cleanup:', error);
        throw error;
    }
}

console.log('✅ Full cleanup script loaded!');
console.log('Run: await fullCleanup()');
