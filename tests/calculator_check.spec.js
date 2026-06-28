const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Helper to write key-value pairs to a Hive box in IndexedDB
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

test.describe('BizPOS Premium Calculator UI Verification', () => {
  test.setTimeout(90000);

  test('should open calculator and capture visual screenshots in dark mode', async ({ page }) => {
    // Pipe console logs
    page.on('console', msg => {
      console.log(`[BROWSER LOG] [${msg.type()}] ${msg.text()}`);
    });

    // 1. Visit origin context to create IndexedDB sandbox
    await page.goto('/');
    await expect(page).toHaveTitle(/Biztonic POS/);

    console.log('Seeding mock database with UI style set to Car Dashboard (1)...');

    // Seed Auth Cache
    await seedHiveBox(page, 'auth_cache', {
      'is_offline_logged_in': true,
      'offline_email': 'test_admin@biztonic.pos',
      'cached_uid': 'test_admin_uid'
    });

    // Seed User Profile Cache as Store Owner
    await seedHiveBox(page, 'user_profile_cache', {
      'profile_test_admin_uid': {
        'uid': 'test_admin_uid',
        'name': 'E2E Test Admin',
        'email': 'test_admin@biztonic.pos',
        'role': 'Store Owner'
      }
    });

    // Seed Pinned Store
    await seedHiveBox(page, 'pinned_store', {
      'current_test_admin_uid': {
        'id': 'test_store_id',
        'name': 'E2E Test Store',
        'shortCode': 'E2ETEST'
      }
    });

    // Seed User Accessible Stores
    await seedHiveBox(page, 'cache_user_stores', {
      'stores_test_admin_uid': [
        {
          'id': 'test_store_id',
          'name': 'E2E Test Store',
          'shortCode': 'E2ETEST'
        }
      ]
    });

    // Seed cache_stores (Active addons activated)
    await seedHiveBox(page, 'cache_stores', {
      'test_store_id': {
        'id': 'test_store_id',
        'name': 'E2E Test Store',
        'shortCode': 'E2ETEST',
        'addons': ['table_reservation', 'data_center', 'central_catalog', 'supplier_management', 'kds_management', 'integration_hub', 'customer_management', 'employee_management', 'franchise_management']
      }
    });

    // Seed settings: isDarkMode = true, uiStyle = 1 (Car Dashboard Insights screen)
    await seedHiveBox(page, 'settings', {
      'isDarkMode': true,
      'uiStyle': 1
    });

    console.log('IndexedDB settings initialized! Reloading...');

    // 2. Reload page to initialize app with mock caches
    await page.reload();
    const gp = page.locator('flt-glass-pane');
    await expect(gp).toBeAttached({ timeout: 60000 });
    
    console.log('Waiting for the Dashboard Insights screen to load...');
    await page.waitForTimeout(15000); 

    await page.waitForTimeout(2000);

    // Let's capture the dashboard insights page first to verify it's the correct layout
    await page.screenshot({ path: 'tests/screenshots/dashboard_insights_main.png', fullPage: true });
    copyScreenshot('dashboard_insights_main.png');
    console.log('Captured: Dashboard Insights Main Screen');

    // Find and click the Calculator button
    console.log('Clicking Calculator button on canvas...');
    await page.mouse.click(900, 225);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'tests/screenshots/calculator_premium_ui.png', fullPage: true });
    copyScreenshot('calculator_premium_ui.png');
    console.log('Calculator visual snapshot captured successfully!');
  });
});
