#!/usr/bin/env bash
# iTantra - Android SDK Quick Setup Script for Linux Mint / Ubuntu

echo "======================================================================"
echo "📦 Installing Android SDK & Build Tools..."
echo "======================================================================"

# 1. Install Android SDK packages from apt
sudo apt update
sudo apt install -y android-sdk android-sdk-platform-tools default-jdk

# 2. Configure Flutter to use Android SDK
export ANDROID_HOME=/usr/lib/android-sdk
flutter config --android-sdk /usr/lib/android-sdk

echo "======================================================================"
echo "✅ Android SDK configured at /usr/lib/android-sdk"
echo "🚀 Now building APK..."
echo "======================================================================"

cd /home/yeswanth/itantra/flutter_app
flutter build apk --release
