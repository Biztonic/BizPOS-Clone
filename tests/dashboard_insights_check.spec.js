const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Helper to write a key-value pair to a Hive box in IndexedDB
async function seedHiveBox(page, boxName, keysAndValues) {
  await page.evaluate(async ({ box, data }) => {
    return new Promise((resolve, reject) => {
      const dbName = box;
      const request = indexedDB.open(dbName, 1);
      
      request.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('box')) {
          db.createObjectStore('box');
        }
      };

      request.onsuccess = (e) => {
        const db = e.target.result;
        const transaction = db.transaction(['box'], 'readwrite');
        const store = transaction.objectStore('box');
        
        for (const [key, value] of Object.entries(data)) {
          store.put(value, key);
        }
        
        transaction.oncomplete = () => {
          db.close();
          resolve();
        };
        transaction.onerror = (err) => {
          db.close();
          reject(err);
        };
      };

      request.onerror = (err) => {
        reject(err);
      };
    });
  }, { box: boxName, data: keysAndValues });
}

// Helper to copy screenshots to the appData brain directory for visibility
function copyScreenshot(srcName) {
  const destDir = 'C:\\Users\\Administrator\\.gemini\\antigravity\\brain\\6115f434-f8fe-4c03-8de4-57c155e32a5b';
  const srcPath = path.join('tests', 'screenshots', srcName);
  const destPath = path.join(destDir, srcName);
  try {
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    fs.copyFileSync(srcPath, destPath);
    console.log(`Copied screenshot from ${srcPath} to ${destPath}`);
  } catch (err) {
    console.error(`Failed to copy screenshot ${srcName}:`, err);
  }
}

test.describe('Dashboard Insights Redesign Verification', () => {
  test.setTimeout(90000);

  test('should verify insights cards in both subscribed and unsubscribed states', async ({ page }) => {
    page.on('console', msg => {
      console.log(`[BROWSER LOG] [${msg.type()}] ${msg.text()}`);
    });

    // 1. Set origin context
    await page.goto('/');
    await expect(page).toHaveTitle(/Biztonic POS/);
    await expect(page.locator('flt-glass-pane')).toBeAttached({ timeout: 60000 });
    await page.waitForTimeout(5000); // Allow first load compilation to finish completely

    // 2. Seed IndexedDB with all addons active (subscribed state)
    console.log('Seeding offline session credentials for SUBSCRIBED state...');
    await seedHiveBox(page, 'auth_cache', {
      'is_offline_logged_in': true,
      'offline_email': 'test_admin@biztonic.pos',
      'cached_uid': 'test_admin_uid'
    });
    await seedHiveBox(page, 'user_profile_cache', {
      'profile_test_admin_uid': {
        'uid': 'test_admin_uid',
        'name': 'E2E Test Admin',
        'email': 'test_admin@biztonic.pos',
        'role': 'Store Owner'
      }
    });
    await seedHiveBox(page, 'pinned_store', {
      'current_test_admin_uid': {
        'id': 'test_store_id',
        'name': 'E2E Test Store',
        'shortCode': 'E2ETEST'
      }
    });
    await seedHiveBox(page, 'cache_user_stores', {
      'stores_test_admin_uid': [
        {
          'id': 'test_store_id',
          'name': 'E2E Test Store',
          'shortCode': 'E2ETEST'
        }
      ]
    });
    await seedHiveBox(page, 'cache_stores', {
      'test_store_id': {
        'id': 'test_store_id',
        'name': 'E2E Test Store',
        'shortCode': 'E2ETEST',
        'addons': [
          'supplier_management',
          'customer_management'
        ]
      }
    });
    await seedHiveBox(page, 'settings', {
      'isDarkMode': true,
      'uiStyle': 1
    });

    // Reload to apply mock DB state
    await page.reload();
    await page.waitForTimeout(15000); // Wait for Flutter rendering

    // Capture subscribed state
    await page.screenshot({ path: 'tests/screenshots/dashboard_insights_subscribed.png', fullPage: true });
    copyScreenshot('dashboard_insights_subscribed.png');
    console.log('Captured subscribed insights card layouts.');

    // 3. Test interactive Analog Clock click
    console.log('Clicking the center of the Analog Clock to trigger spin animation...');
    // Coordinate calculation: center of clock card in 1280x720 viewport is approx (289, 586)
    await page.mouse.click(289, 586);
    await page.waitForTimeout(1500); // Let spin animation complete

    // Capture clock during/after spin
    await page.screenshot({ path: 'tests/screenshots/dashboard_insights_clock_spin.png', fullPage: true });
    copyScreenshot('dashboard_insights_clock_spin.png');
    console.log('Captured analog clock sweep animation screenshot.');

    // 4. Seed IndexedDB with addons disabled (unsubscribed state)
    console.log('Seeding offline session credentials for UNSUBSCRIBED state...');
    await seedHiveBox(page, 'cache_stores', {
      'test_store_id': {
        'id': 'test_store_id',
        'name': 'E2E Test Store',
        'shortCode': 'E2ETEST',
        'addons': [] // Empty addons list to lock supplier/customer quick access cards
      }
    });

    // Reload to apply mock DB state
    await page.reload();
    await page.waitForTimeout(15000); // Wait for Flutter rendering

    // Capture unsubscribed state
    await page.screenshot({ path: 'tests/screenshots/dashboard_insights_unsubscribed.png', fullPage: true });
    copyScreenshot('dashboard_insights_unsubscribed.png');
    console.log('Captured unsubscribed insights card layouts.');
  });
});
