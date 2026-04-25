# Simple Step-by-Step Guide for BiztonicPOS

Follow these steps one by one. You do not need to be an IT expert!

## Step 1: Install Flutter (If you haven't already)
1.  Go to this website: [https://docs.flutter.dev/get-started/install/windows/mobile](https://docs.flutter.dev/get-started/install/windows/mobile)
2.  Download the **Flutter SDK** zip file.
3.  Extract the zip file to a simple place like `C:\src\flutter` (create the folder if it doesn't exist).
4.  **Important**: You need to update your "Path" variable.
    *   Press the **Windows Key** and type "env".
    *   Click "Edit the system environment variables".
    *   Click the **Environment Variables** button.
    *   In the "User variables" box, find **Path** and double-click it.
    *   Click **New** and type: `C:\src\flutter\bin`
    *   Click OK on all windows.

## Step 2: Prepare the App
1.  Press the **Windows Key** and type "PowerShell".
2.  Right-click it and select **Run as Administrator**.
3.  Copy and paste this command (then press Enter):
    ```powershell
    cd C:\Users\Administrator\BiztonicPOS_Flutter
    ```
4.  Now copy and paste this command:
    ```powershell
    flutter create .
    ```
    *(This builds the internal engine of the app. It might take a minute.)*

## Step 3: Connect Your Backend (Firebase)
1.  Go to your [Firebase Console](https://console.firebase.google.com/) in your browser.
2.  Click on your project.
3.  Click the **Gear icon** (Settings) > **Project settings**.
4.  Scroll down to "Your apps".
5.  **For Android**:
    *   Select the Android app (or create one with package name `com.example.biztonic_pos`).
    *   Download the `google-services.json` file.
    *   Copy that file into this folder on your computer:
        `C:\Users\Administrator\BiztonicPOS_Flutter\android\app\`

## Step 4: Run the App
1.  Go back to your PowerShell window.
2.  Connect your Android phone via USB (or open an Emulator).
3.  Type this command and press Enter:
    ```powershell
    flutter run
    ```

**That's it! Your app should start.**
