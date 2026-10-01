# iTantra - Android SDK Installation & APK Build Guide

This guide explains how to fix `[!] No Android SDK found` and build your `.apk` file on Linux Mint / Ubuntu.

---

## 🛠️ Step 1: Install Android SDK on Linux

Run this command in your terminal to install the Android SDK tools:

```bash
sudo apt update && sudo apt install -y android-sdk android-sdk-platform-tools default-jdk
```

---

## ⚙️ Step 2: Configure Flutter with Android SDK Location

Set the Android SDK path in Flutter:

```bash
flutter config --android-sdk /usr/lib/android-sdk
export ANDROID_HOME=/usr/lib/android-sdk
```

Verify by running:
```bash
flutter doctor
```

---

## 🚀 Step 3: Build the Release APK

Navigate into the Flutter project directory and build the APK:

```bash
cd /home/yeswanth/itantra/flutter_app
flutter pub get
flutter build apk --release
```

- **Output APK Location**:  
  `flutter_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 📱 Step 4: Install & Run on Mobile Phone

- **Option A (Via USB ADB)**:
  Connect phone via USB with USB Debugging enabled:
  ```bash
  adb install build/app/outputs/flutter-apk/app-release.apk
  ```

- **Option B (Via Local Wi-Fi Web Server)**:
  Serve the build folder over Wi-Fi:
  ```bash
  cd build/app/outputs/flutter-apk/
  python3 -m http.server 8000
  ```
  On your mobile browser, open `http://<YOUR_COMPUTER_IP>:8000/app-release.apk` to download and install!
