#!/usr/bin/env bash
# iTantra - Standalone Android SDK Installer (No sudo required)

set -e

SDK_DIR="$HOME/android-sdk"
mkdir -p "$SDK_DIR/cmdline-tools"

echo "======================================================================"
echo "📥 Downloading official Google Android Command Line Tools..."
echo "======================================================================"

cd "$SDK_DIR/cmdline-tools"
if [ ! -d "latest" ]; then
    wget -q --show-progress https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    mv cmdline-tools latest
    rm cmdline-tools.zip
fi

export ANDROID_HOME="$SDK_DIR"
export PATH="$PATH:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools"

echo "======================================================================"
echo "⚙️ Installing Android SDK Platform & Build-Tools..."
echo "======================================================================"

yes | "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null 2>&1 || true
"$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "platforms;android-34" "build-tools;34.0.0"

flutter config --android-sdk "$SDK_DIR"

echo "======================================================================"
echo "✅ Android SDK configured cleanly at $SDK_DIR"
echo "🚀 Building Flutter APK..."
echo "======================================================================"

cd /home/yeswanth/itantra/flutter_app
flutter build apk --release
