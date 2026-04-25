# BizPOS Deployment Guide

## 🚀 Setting up a Fresh Environment

When pulling this repository from GitHub, the environment-specific configuration files (API keys, Firebase Config) will be missing because they are **git-ignored** for security.

### 1. Prerequisites
- **Flutter SDK** installed and in PATH.
- **Firebase CLI** (`npm install -g firebase-tools`).
- **Java JDK 17** (Required for Android Build).

### 2. Automated Setup
We have provided a PowerShell script to automate the configuration of a new Firebase backend and generate the necessary keys.

1. Open a terminal in the project root.
2. Run the setup script:
   ```powershell
   ./setup_backend.ps1
   ```
3. Follow the interactive prompts:
   - **Login** to your Google/Firebase account.
   - **Select/Create Project**: Choose "Create a new project" to set up a fresh backend.
   - **Select Platforms**: Ensure `android`, `ios`, and `web` are selected.

### 3. Manual Steps (Firebase Console)
After the script finishes, you **must** perform these manual steps in the [Firebase Console](https://console.firebase.google.com/):

1. **Authentication**: 
   - Go to **Build > Authentication > Sign-in method**.
   - Enable **Email/Password**.
2. **Firestore**:
   - Go to **Build > Firestore Database**.
   - Ensure the database is created (the script deploys rules, but the DB instance must exist).
3. **Storage** (Optional):
   - Enable **Storage** if you plan to use image uploads.

### 4. Build the App
Once setup is complete, you can build the application:

```bash
flutter pub get
flutter run
# OR
flutter build apk --release
```
