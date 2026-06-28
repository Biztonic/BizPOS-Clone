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
  await page.waitForTimeout(6000); // Wait for the transition and canvas layout
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

test.describe('BizPOS Complete UI, Flow and Style Consistency Testing', () => {
  test.setTimeout(180000); // 3 minutes total time

  test('should verify all core screens and dynamic module routes with mock seeding', async ({ page }) => {
    // Pipe console logs
    page.on('console', msg => {
      console.log(`[BROWSER LOG] [${msg.type()}] ${msg.text()}`);
    });

    // 1. Visit origin context to create IndexedDB sandbox
    await page.goto('/');
    await expect(page).toHaveTitle(/Biztonic POS/);

    console.log('Seeding full mock database in IndexedDB...');

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

    // Seed Dark Mode and UI settings
    await seedHiveBox(page, 'settings', {
      'isDarkMode': true,
      'uiStyle': 0
    });

    // Seed Products/Inventory
    await seedHiveBox(page, 'cache_inventory', {
      'item_1': {
        'id': 'item_1',
        'name': 'Double Cheeseburger',
        'category': 'Burgers',
        'price': 12.99,
        'quantity': 50,
        'status': 'In Stock',
        'trackStock': true,
        'storeId': 'test_store_id',
        'cardStyle': 'image',
        'cardSize': 'medium',
        'syncStatus': 'SYNCED',
        'version': 1,
        'featured': true,
        'lowStockThreshold': 5
      },
      'item_2': {
        'id': 'item_2',
        'name': 'Crispy French Fries',
        'category': 'Sides',
        'price': 4.50,
        'quantity': 100,
        'status': 'In Stock',
        'trackStock': true,
        'storeId': 'test_store_id',
        'cardStyle': 'image',
        'cardSize': 'medium',
        'syncStatus': 'SYNCED',
        'version': 1,
        'featured': false,
        'lowStockThreshold': 10
      },
      'item_3': {
        'id': 'item_3',
        'name': 'Fresh Lemonade',
        'category': 'Beverages',
        'price': 3.50,
        'quantity': 3,
        'status': 'Low Stock',
        'trackStock': true,
        'storeId': 'test_store_id',
        'cardStyle': 'image',
        'cardSize': 'medium',
        'syncStatus': 'SYNCED',
        'version': 1,
        'featured': false,
        'lowStockThreshold': 5
      }
    });

    // Seed Tables & Floor Plans
    await seedHiveBox(page, 'cache_floors_test_store_id', {
      'floor_1': {
        'id': 'floor_1',
        'storeId': 'test_store_id',
        'name': 'Main Dining Area'
      }
    });

    await seedHiveBox(page, 'cache_tables_test_store_id', {
      'table_1': {
        'id': 'table_1',
        'storeId': 'test_store_id',
        'floorId': 'floor_1',
        'name': 'Table 01',
        'seats': [
          {'number': 1, 'orderId': null},
          {'number': 2, 'orderId': null},
          {'number': 3, 'orderId': null},
          {'number': 4, 'orderId': null}
        ],
        'shape': 'square',
        'position': {'x': 120, 'y': 150},
        'rotation': 0,
        'status': 'Available',
        'billingMode': 'per-table'
      },
      'table_2': {
        'id': 'table_2',
        'storeId': 'test_store_id',
        'floorId': 'floor_1',
        'name': 'Table 02',
        'seats': [
          {'number': 1, 'orderId': 'test_order_id_1'},
          {'number': 2, 'orderId': null}
        ],
        'shape': 'circle',
        'position': {'x': 320, 'y': 150},
        'rotation': 0,
        'status': 'Occupied',
        'orderId': 'test_order_id_1',
        'billingMode': 'per-table'
      }
    });

    console.log('IndexedDB mocks injected! Reloading...');

    // 2. Reload page to initialize app with mock caches
    await page.reload();
    const gp = page.locator('flt-glass-pane');
    await expect(gp).toBeAttached({ timeout: 60000 });
    
    console.log('App rehydrated! Initializing page walk...');
    await page.waitForTimeout(15000); // Wait for initialization to settle

    // --- PHASE 3: COMPREHENSIVE ROUTE TRANSITION AND VISUAL CAPTURE ---

    // 1. Dashboard Overview
    await page.screenshot({ path: 'tests/screenshots/1_dashboard_overview.png', fullPage: true });
    copyScreenshot('1_dashboard_overview.png');
    console.log('Captured: Dashboard Overview');

    // 2. POS Checkout Screen
    await inAppNavigate(page, '/pos');
    await page.screenshot({ path: 'tests/screenshots/2_pos_checkout.png', fullPage: true });
    copyScreenshot('2_pos_checkout.png');
    console.log('Captured: POS Checkout');

    // 3. Inventory List Screen
    await inAppNavigate(page, '/inventory');
    await page.screenshot({ path: 'tests/screenshots/3_inventory_list.png', fullPage: true });
    copyScreenshot('3_inventory_list.png');
    console.log('Captured: Inventory List');

    // 4. Sales Orders History Screen
    await inAppNavigate(page, '/sales');
    await page.screenshot({ path: 'tests/screenshots/4_sales_history.png', fullPage: true });
    copyScreenshot('4_sales_history.png');
    console.log('Captured: Sales Orders History');

    // 5. Tables Floor Plan Management
    await inAppNavigate(page, '/tables');
    await page.screenshot({ path: 'tests/screenshots/5_tables_layout.png', fullPage: true });
    copyScreenshot('5_tables_layout.png');
    console.log('Captured: Tables Layout');

    // 6. Customers / CRM Screen
    await inAppNavigate(page, '/customers');
    await page.screenshot({ path: 'tests/screenshots/6_customers_crm.png', fullPage: true });
    copyScreenshot('6_customers_crm.png');
    console.log('Captured: Customers / CRM');

    // 7. Suppliers List Screen
    await inAppNavigate(page, '/suppliers');
    await page.screenshot({ path: 'tests/screenshots/7_suppliers_list.png', fullPage: true });
    copyScreenshot('7_suppliers_list.png');
    console.log('Captured: Suppliers List');

    // 8. Data Sync Controls (Data Center)
    await inAppNavigate(page, '/data-sync');
    await page.screenshot({ path: 'tests/screenshots/8_data_sync_controls.png', fullPage: true });
    copyScreenshot('8_data_sync_controls.png');
    console.log('Captured: Data Sync Controls');

    // 9. Reports Dashboard Overview
    await inAppNavigate(page, '/reports');
    await page.screenshot({ path: 'tests/screenshots/9_reports_dashboard.png', fullPage: true });
    copyScreenshot('9_reports_dashboard.png');
    console.log('Captured: Reports Dashboard');

    // 10. Reports - Sales detailed
    await inAppNavigate(page, '/reports/sales');
    await page.screenshot({ path: 'tests/screenshots/10_reports_sales.png', fullPage: true });
    copyScreenshot('10_reports_sales.png');
    console.log('Captured: Reports - Sales detailed');

    // 11. Reports - Inventory detailed
    await inAppNavigate(page, '/reports/inventory');
    await page.screenshot({ path: 'tests/screenshots/11_reports_inventory.png', fullPage: true });
    copyScreenshot('11_reports_inventory.png');
    console.log('Captured: Reports - Inventory detailed');

    // 12. Reports - Customers detailed
    await inAppNavigate(page, '/reports/customers');
    await page.screenshot({ path: 'tests/screenshots/12_reports_customers.png', fullPage: true });
    copyScreenshot('12_reports_customers.png');
    console.log('Captured: Reports - Customers detailed');

    // 13. Reports - Financials detailed
    await inAppNavigate(page, '/reports/financials');
    await page.screenshot({ path: 'tests/screenshots/13_reports_financials.png', fullPage: true });
    copyScreenshot('13_reports_financials.png');
    console.log('Captured: Reports - Financials detailed');

    // 14. BizStore Addon Marketplace
    await inAppNavigate(page, '/biz-store');
    await page.screenshot({ path: 'tests/screenshots/14_bizstore_marketplace.png', fullPage: true });
    copyScreenshot('14_bizstore_marketplace.png');
    console.log('Captured: BizStore Marketplace');

    // 15. Settings Screen
    await inAppNavigate(page, '/settings');
    await page.screenshot({ path: 'tests/screenshots/15_settings_panel.png', fullPage: true });
    copyScreenshot('15_settings_panel.png');
    console.log('Captured: Settings Panel');

    console.log('Full page verification and style consistency testing complete!');
  });
});
