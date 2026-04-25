# BiztonicPOS (Flutter)

This is the Flutter implementation of the Biztonic POS system.

## 🚀 Getting Started

Since this project was generated without the Flutter SDK present, you need to "hydrate" it first.

1.  **Open Terminal** in this folder.
2.  Run the following command to generate Android/iOS build files:
    ```bash
    flutter create .
    ```
3.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

## 🔥 Firebase Setup (CRITICAL)

To connect to your **existing Firebase project**, you must download the configuration files from the Firebase Console.

### Android
1.  Go to [Firebase Console](https://console.firebase.google.com/).
2.  Open your project settings.
3.  Download `google-services.json`.
4.  Place it in: `android/app/google-services.json`.

### iOS
1.  Go to [Firebase Console](https://console.firebase.google.com/).
2.  Open your project settings.
3.  Download `GoogleService-Info.plist`.
4.  Place it in: `ios/Runner/GoogleService-Info.plist`.

## 📱 Hardware Integration

This app is pre-configured with dependencies for:
*   **Bluetooth Printers**: `flutter_blue_plus`
*   **Thermal Printing**: `printing`
*   **Offline Database**: `hive`

## 🏃‍♂️ Running the App

```bash
flutter run
```
