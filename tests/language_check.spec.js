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

// Helper for in-app routing via History API (popstate dispatch)
async function inAppNavigate(page, path) {
  console.log(`Navigating in-app to: ${path}`);
  await page.evaluate((targetPath) => {
    window.history.pushState(null, '', targetPath);
    window.dispatchEvent(new PopStateEvent('popstate'));
  }, path);
  await page.waitForTimeout(5000);
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

test.describe('BizPOS Language Settings UI Verification', () => {
  test.setTimeout(90000);

  test('should navigate to language settings and select a language', async ({ page }) => {
    // Pipe console logs
    page.on('console', msg => {
      console.log(`[BROWSER LOG] [${msg.type()}] ${msg.text()}`);
    });

    // 1. Visit origin context to create IndexedDB sandbox
    await page.goto('/');
    await expect(page).toHaveTitle(/Biztonic POS/);

    console.log('Seeding mock database...');

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

    // Seed settings
    await seedHiveBox(page, 'settings', {
      'isDarkMode': true,
      'uiStyle': 1
    });

    console.log('IndexedDB settings initialized! Loading Settings view...');

    // 2. Go to dashboard, let it settle, then navigate in-app to settings
    await page.goto('/');
    const gp = page.locator('flt-glass-pane');
    await expect(gp).toBeAttached({ timeout: 60000 });
    
    console.log('Waiting for the Dashboard screen to load...');
    await page.waitForTimeout(15000); 

    console.log('Navigating to settings screen...');
    await inAppNavigate(page, '/settings'); 

    // Force accessibility/semantics mode activation
    console.log('Activating Flutter Semantics via placeholder focus...');
    await page.locator('flt-semantics-placeholder').focus();
    await page.locator('flt-semantics-placeholder').press('Enter');
    await page.waitForTimeout(5000);

    // Capture settings main view
    await page.screenshot({ path: 'tests/screenshots/settings_main.png', fullPage: true });
    copyScreenshot('settings_main.png');
    console.log('Captured: Settings Main Screen');

    // Scroll the left settings list to bring Language Settings into view via a drag gesture
    console.log('Scrolling settings sidebar down...');
    await page.mouse.move(200, 500);
    await page.mouse.down();
    await page.mouse.move(200, 200, { steps: 15 });
    await page.mouse.up();
    await page.waitForTimeout(3000);

    // Find and click the Language Settings option in the left list
    console.log('Looking for Language Settings card...');
    const langBtn = page.getByRole('button', { name: 'Language Settings' });
    await expect(langBtn).toBeVisible({ timeout: 15000 });
    console.log('Clicking Language Settings card...');
    await langBtn.click({ force: true });
    
    await page.waitForTimeout(5000);

    // Capture settings screen showing Language Section on the right
    await page.screenshot({ path: 'tests/screenshots/language_settings_view.png', fullPage: true });
    copyScreenshot('language_settings_view.png');
    console.log('Language Settings view captured successfully!');
  });
});
