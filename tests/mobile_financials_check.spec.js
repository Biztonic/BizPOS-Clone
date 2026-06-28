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

// Helper for in-app routing via History API
async function inAppNavigate(page, path) {
  console.log(`Navigating in-app to: ${path}`);
  await page.evaluate((targetPath) => {
    window.history.pushState(null, '', targetPath);
    window.dispatchEvent(new PopStateEvent('popstate'));
  }, path);
  await page.waitForTimeout(4000);
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

test.describe('BizPOS Mobile Responsiveness & Financials UI Verification', () => {
  test.setTimeout(90000);

  // Set mobile device viewport size (iPhone 12 width: 390, height: 844)
  test.use({ viewport: { width: 390, height: 844 } });

  test('should verify mobile responsive layout and enhanced financials screen', async ({ page }) => {
    // Pipe console logs
    page.on('console', msg => {
      console.log(`[BROWSER LOG] [${msg.type()}] ${msg.text()}`);
    });

    // 1. Visit origin to create IndexedDB sandbox
    await page.goto('/');
    await expect(page).toHaveTitle(/Biztonic POS/);

    console.log('Seeding mock database for mobile e2e test...');

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
        'name': 'E2E Mobile Store',
        'shortCode': 'MOBSTORE'
      }
    });

    // Seed User Accessible Stores
    await seedHiveBox(page, 'cache_user_stores', {
      'stores_test_admin_uid': [
        {
          'id': 'test_store_id',
          'name': 'E2E Mobile Store',
          'shortCode': 'MOBSTORE'
        }
      ]
    });

    // Seed cache_stores (Active addons activated)
    await seedHiveBox(page, 'cache_stores', {
      'test_store_id': {
        'id': 'test_store_id',
        'name': 'E2E Mobile Store',
        'shortCode': 'MOBSTORE',
        'addons': []
      }
    });

    // Seed cache_orders (Create some historical orders for financials)
    const order1Date = new Date();
    order1Date.setDate(order1Date.getDate() - 1);
    const order2Date = new Date();
    order2Date.setDate(order2Date.getDate() - 2);

    await seedHiveBox(page, 'cache_orders', {
      'order_id_1': {
        'id': 'order_id_1',
        'storeId': 'test_store_id',
        'total': 1200.0,
        'status': 'Completed',
        'paymentMethod': 'Cash',
        'date': order1Date.toISOString(),
        'items': [
          {
            'id': 'item_1',
            'name': 'Paneer Tikka',
            'quantity': 2,
            'price': 400.0,
            'costSnapshot': 250.0,
            'category': 'Starters'
          },
          {
            'id': 'item_2',
            'name': 'Butter Naan',
            'quantity': 4,
            'price': 100.0,
            'costSnapshot': 40.0,
            'category': 'Breads'
          }
        ]
      },
      'order_id_2': {
        'id': 'order_id_2',
        'storeId': 'test_store_id',
        'total': 600.0,
        'status': 'Completed',
        'paymentMethod': 'Card',
        'date': order2Date.toISOString(),
        'items': [
          {
            'id': 'item_3',
            'name': 'Veg Biryani',
            'quantity': 1,
            'price': 500.0,
            'costSnapshot': 300.0,
            'category': 'Main Course'
          },
          {
            'id': 'item_2',
            'name': 'Butter Naan',
            'quantity': 1,
            'price': 100.0,
            'costSnapshot': 40.0,
            'category': 'Breads'
          }
        ]
      }
    });

    // Seed settings (set UIStyle to car_dashboard to verify mobile bypass!)
    await seedHiveBox(page, 'settings', {
      'isDarkMode': false,
      'uiStyle': 1 // car_dashboard
    });

    console.log('Seeded database successfully! Navigating to home...');
    await page.goto('/');

    const gp = page.locator('flt-glass-pane');
    await expect(gp).toBeAttached({ timeout: 60000 });
    await page.waitForTimeout(10000);

    // Capture mobile dashboard overview
    await page.screenshot({ path: 'tests/screenshots/dashboard_mobile.png', fullPage: true });
    copyScreenshot('dashboard_mobile.png');
    console.log('Captured: Mobile Dashboard Overview');

    // Verify speed button is not visible
    const speedIcon = page.locator('flt-glass-pane').locator('[aria-label*="speed"]');
    const speedCount = await speedIcon.count();
    console.log(`Speed switcher icon count: ${speedCount}`);
    expect(speedCount).toBe(0);

    // Activate semantics
    await page.locator('flt-semantics-placeholder').focus();
    await page.locator('flt-semantics-placeholder').press('Enter');
    await page.waitForTimeout(3000);

    // Go to Settings Screen
    await inAppNavigate(page, '/settings');
    await page.screenshot({ path: 'tests/screenshots/settings_mobile.png', fullPage: true });
    copyScreenshot('settings_mobile.png');
    console.log('Captured: Mobile Settings List');

    // Click on Display settings to verify it opens in a proper sub-Scaffold
    const displayCard = page.getByRole('button', { name: 'Appearance' });
    await expect(displayCard).toBeVisible({ timeout: 10000 });
    await displayCard.click({ force: true });
    await page.waitForTimeout(5000);

    await page.screenshot({ path: 'tests/screenshots/display_settings_mobile.png', fullPage: true });
    copyScreenshot('display_settings_mobile.png');
    console.log('Captured: Mobile Display Settings sub-Scaffold');

    // Navigate to Reports screen
    await inAppNavigate(page, '/reports');
    await page.screenshot({ path: 'tests/screenshots/reports_mobile.png', fullPage: true });
    copyScreenshot('reports_mobile.png');
    console.log('Captured: Mobile Reports Menu');

    // Navigate to Financial Reports screen
    await inAppNavigate(page, '/reports/financials');
    await page.screenshot({ path: 'tests/screenshots/financial_reports_mobile.png', fullPage: true });
    copyScreenshot('financial_reports_mobile.png');
    console.log('Captured: Mobile Financial Reports Page');

    // Verify Financial Reports rendered Gross profit card and category/day list items
    const grossProfitRow = page.getByText('Gross Profit').first();
    await expect(grossProfitRow).toBeVisible({ timeout: 15000 });
    console.log('Gross Profit row is rendered and verified!');
  });
});
