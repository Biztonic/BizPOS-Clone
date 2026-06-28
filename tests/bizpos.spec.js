const { test, expect } = require('@playwright/test');

test.describe('BizPOS Web Application tests', () => {
  test('should load the dashboard successfully', async ({ page }) => {
    // 1. Navigate to the application
    console.log('Navigating to BizPOS web application...');
    await page.goto('/');

    // 2. Verify that the title is correct
    console.log('Verifying page title...');
    await expect(page).toHaveTitle(/Biztonic POS/);

    // 3. Wait for the Flutter glass pane to be present (indicates engine loaded successfully)
    console.log('Waiting for Flutter app engine to render (<flt-glass-pane>)...');
    const glassPane = page.locator('flt-glass-pane');
    await expect(glassPane).toBeAttached({ timeout: 60000 });

    // 4. Give the app dynamic elements a brief moment to stabilize
    await page.waitForTimeout(5000);

    // 5. Take a screenshot for visual E2E validation
    console.log('Capturing screen capture for visual validation...');
    await page.screenshot({ path: 'tests/screenshots/dashboard.png', fullPage: true });
    console.log('Dashboard screenshot captured successfully at tests/screenshots/dashboard.png!');
  });
});
