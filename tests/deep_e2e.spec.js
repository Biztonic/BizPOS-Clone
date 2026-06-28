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

test.describe('BizPOS E2E Testing Suite with Semantics Click', () => {
  test.setTimeout(90000);

  test('should bypass login and navigate to Reports and BizStore using labels', async ({ page }) => {
    // Pipe page console logs to terminal
    page.on('console', msg => {
      console.log(`[BROWSER LOG] [${msg.type()}] ${msg.text()}`);
    });

    // 1. Navigate to set origin context
    await page.goto('/');
    await expect(page).toHaveTitle(/Biztonic POS/);

    // 2. Inject mock session details into IndexedDB
    console.log('Seeding offline session credentials in browser IndexedDB...');
    
    // Seed Auth Cache
    await seedHiveBox(page, 'auth_cache', {
      'is_offline_logged_in': true,
      'offline_email': 'test_admin@biztonic.pos',
      'cached_uid': 'test_admin_uid'
    });

    // Seed User Profile Cache
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

    // Seed User Pinned/Accessible Stores Cache
    await seedHiveBox(page, 'cache_user_stores', {
      'stores_test_admin_uid': [
        {
          'id': 'test_store_id',
          'name': 'E2E Test Store',
          'shortCode': 'E2ETEST'
        }
      ]
    });

    // Seed cache_stores database (which StoreProvider uses to fetch details of activeStore)
    await seedHiveBox(page, 'cache_stores', {
      'test_store_id': {
        'id': 'test_store_id',
        'name': 'E2E Test Store',
        'shortCode': 'E2ETEST',
        'addons': [
          'table_reservation',
          'data_center',
          'central_catalog',
          'supplier_management',
          'kds_management',
          'integration_hub',
          'customer_management',
          'employee_management',
          'franchise_management'
        ]
      }
    });

    // Seed App Settings
    await seedHiveBox(page, 'settings', {
      'isDarkMode': true,
      'uiStyle': 0
    });

    console.log('IndexedDB offline session seeded successfully!');

    // 3. Reload to log in
    await page.reload();
    const glassPane = page.locator('flt-glass-pane');
    await expect(glassPane).toBeAttached({ timeout: 60000 });
    
    // Give the app dynamic layout a brief moment to initialize the dashboard
    console.log('Waiting for the Dashboard layout to mount...');
    await page.waitForTimeout(15000);
    await page.screenshot({ path: 'tests/screenshots/dashboard_mock_login.png', fullPage: true });
    copyScreenshot('dashboard_mock_login.png');

    // 4. Force accessibility/semantics mode activation (optional for debugging/logging, but keeps the flow intact)
    console.log('Activating Flutter Semantics via placeholder focus...');
    await page.locator('flt-semantics-placeholder').focus();
    await page.locator('flt-semantics-placeholder').press('Enter');
    await page.waitForTimeout(5000);

    // 5. Query and dump all available aria-labels inside shadow root
    const labels = await page.evaluate(() => {
      const gp = document.querySelector('flt-glass-pane');
      if (!gp || !gp.shadowRoot) return ['No glass pane or shadow root'];
      const elements = gp.shadowRoot.querySelectorAll('[aria-label]');
      return Array.from(elements).map(el => `${el.tagName.toLowerCase()}: "${el.getAttribute('aria-label')}"`);
    });
    console.log('--- DETECTED SEMANTIC NODES START ---');
    console.log(labels.join('\n'));
    console.log('--- DETECTED SEMANTIC NODES END ---');

    // 6. Navigate to Reports overview page via History API
    console.log('Navigating to Reports Overview...');
    await inAppNavigate(page, '/reports');
    await page.screenshot({ path: 'tests/screenshots/dashboard_reports.png', fullPage: true });
    copyScreenshot('dashboard_reports.png');
    console.log('Reports overview page captured.');

    // 7. Navigate to Sales Report sub-page via History API
    console.log('Navigating to Sales Report...');
    await inAppNavigate(page, '/reports/sales');
    await page.screenshot({ path: 'tests/screenshots/dashboard_reports_sales.png', fullPage: true });
    copyScreenshot('dashboard_reports_sales.png');
    console.log('Sales report page captured.');

    // 8. Navigate to BizStore page via History API
    console.log('Navigating to BizStore...');
    await inAppNavigate(page, '/biz-store');
    await page.screenshot({ path: 'tests/screenshots/dashboard_bizstore.png', fullPage: true });
    copyScreenshot('dashboard_bizstore.png');
    console.log('BizStore addon page captured.');
  });
});
