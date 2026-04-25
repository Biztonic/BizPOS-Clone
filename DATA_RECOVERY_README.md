# ⚠️ CRITICAL: Production Data Safety

## What Happened

The `DANGEROUS_reconstruct_backend.dart` script was run on the production Firebase database and **deleted all production data**. This included:
- All customer orders
- All inventory items
- All customer records
- All employee data
- All table/floor configurations

## Current State

**Two stores exist in the database:**
1. **BizTonic HQ (Super Store)** - ID: `d65d816a-338a-46ee-b102-1066c2d1329e`
   - Contains test data (10 orders, 15 inventory items, 5 customers, etc.)
   
2. **Sudama New** - ID: `7htlU4GbAOztGJHqkheR`
   - **EMPTY** - Production data was deleted

## Data Recovery Options

### Option 1: Firebase Backups (Recommended)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `biztonic-pos`
3. Navigate to **Firestore Database** → **Backups**
4. Check if automated backups exist (Blaze plan includes backups)
5. If backups exist, contact Firebase Support for restoration

### Option 2: Contact Firebase Support
- Email: firebase-support@google.com
- Explain the situation and request data recovery assistance
- Provide project ID: `biztonic-pos` (50556399451)

### Option 3: Local Cache Recovery
Some data might still exist in local Hive caches on devices that used the app recently:
- Check `cache_orders`, `cache_inventory`, `cache_customers` boxes
- Export data before clearing cache

## Prevention Measures Implemented

✅ **Files Renamed:**
- `reconstruct_backend.dart` → `DANGEROUS_reconstruct_backend.dart`
- `run_reconstruction.dart` → `DANGEROUS_run_reconstruction.dart`

✅ **Warning Banners Added:**
- Prominent warnings at the top of both files
- Clear indication that running these scripts will delete ALL data

## Best Practices Going Forward

### 1. Use Separate Firebase Projects
- **Production**: Real customer data
- **Development**: Test data only
- **Staging**: Pre-production testing

### 2. Regular Backups
- Enable automated Firestore backups
- Export data regularly to Cloud Storage
- Keep local backups of critical data

### 3. Data Export Before Destructive Operations
- Always export data before running scripts that modify/delete data
- Use Firebase Console's export feature
- Store exports in a safe location

### 4. Use Firebase Emulator for Development
```bash
firebase emulators:start
```
- Test locally without touching production data
- No risk of accidental data deletion

### 5. Environment Variables
Add environment checks to scripts:
```dart
const String ENVIRONMENT = String.fromEnvironment('ENV', defaultValue: 'production');

if (ENVIRONMENT == 'production') {
  throw Exception('CANNOT RUN ON PRODUCTION!');
}
```

## Never Run These Files Again

🚫 **DO NOT RUN:**
- `DANGEROUS_reconstruct_backend.dart`
- `DANGEROUS_run_reconstruction.dart`

These files should only be used on development databases with the Firebase Emulator.

## Contact Information

- **Firebase Support**: firebase-support@google.com
- **Project ID**: biztonic-pos (50556399451)
- **Super Admin**: pthorat600@gmail.com
