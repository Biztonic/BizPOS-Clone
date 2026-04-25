Write-Host "=========================================="
Write-Host "   BizPOS Backend Deployment Script       "
Write-Host "=========================================="

# 1. Check Prerequisites
Write-Host "`n[1/5] Checking Prerequisites..."

if (!(Get-Command "firebase" -ErrorAction SilentlyContinue)) {
    Write-Error "Firebase CLI is not installed. Please run: npm install -g firebase-tools"
    exit 1
}

if (!(Get-Command "flutterfire" -ErrorAction SilentlyContinue)) {
    Write-Host "FlutterFire CLI not found. Installing..."
    dart pub global activate flutterfire_cli
}

# 2. Login
Write-Host "`n[2/5] Firebase Login..."
firebase login

# 3. Configure App (Generates firebase_options.dart and google-services.json)
Write-Host "`n[3/5] Configuring Flutter App..."
Write-Host "INSTRUCTIONS:"
Write-Host " - Select 'Create a new project' (or choose an existing empty one)."
Write-Host " - Select platforms: android, ios, web (use Space to select)."
Write-Host " - When asked about bundle IDs, use default or overwrite if prompted."
flutterfire configure

# 4. Deploy Backend Resources
Write-Host "`n[4/5] Deploying Firestore Rules & Indexes..."
# flutterfire configure updates .firebaserc, so firebase deploy should know where to go.
firebase deploy --only firestore

# 5. Final Instructions
Write-Host "`n[5/5] Setup Complete!"
Write-Host "=========================================="
Write-Host "IMPORTANT MANUAL STEPS REQUIRED:"
Write-Host "1. Go to the Firebase Console for your new project."
Write-Host "2. Enable 'Authentication' -> Sign-in method -> Email/Password."
Write-Host "3. Enable 'Firestore Database' (if not already enabled) in 'production' mode."
Write-Host "4. Enable 'Storage' if your app uses image uploads."
Write-Host "=========================================="
Pause
