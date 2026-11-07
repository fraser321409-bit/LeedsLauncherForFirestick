#!/usr/bin/env bash
# Builds LeedsLauncher.apk from the terminal. No Android Studio needed.
# Usage:  ./build.sh                 (just build)
#         ./build.sh 192.168.1.50    (build, then install on your Firestick at that IP)
set -euo pipefail
cd "$(dirname "$0")"

WORK="$HOME/.leeds-build"
export ANDROID_HOME="$WORK/android-sdk"
GRADLE_VER="8.7"
CMDLINE_ZIP="commandlinetools-linux-11076708_latest.zip"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Please install '$1' first (e.g. sudo apt install $2)"; exit 1; }; }
need curl curl
need unzip unzip
need java openjdk-17-jdk

major=$(java -version 2>&1 | awk -F'"' '/version/{split($2,a,"."); print (a[1]=="1")?a[2]:a[1]; exit}')
if [ "${major:-0}" -lt 17 ]; then
  echo "Java 17 or newer is needed (you have ${major:-unknown}). e.g. sudo apt install openjdk-17-jdk"
  exit 1
fi

mkdir -p "$WORK" "$ANDROID_HOME/cmdline-tools"

# 1) Android command-line tools
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo ">> Downloading Android command-line tools..."
  curl -fL -o "$WORK/cmdline.zip" "https://dl.google.com/android/repository/$CMDLINE_ZIP"
  rm -rf "$WORK/cmdline-tmp" && mkdir -p "$WORK/cmdline-tmp"
  unzip -q "$WORK/cmdline.zip" -d "$WORK/cmdline-tmp"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$WORK/cmdline-tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

# 2) SDK pieces
echo ">> Installing SDK packages (first run only, a few minutes)..."
set +o pipefail
yes | "$SDKM" --licenses >/dev/null 2>&1 || true
set -o pipefail
"$SDKM" "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# 3) Gradle
if [ ! -x "$WORK/gradle-$GRADLE_VER/bin/gradle" ]; then
  echo ">> Downloading Gradle $GRADLE_VER..."
  curl -fL -o "$WORK/gradle.zip" "https://services.gradle.org/distributions/gradle-$GRADLE_VER-bin.zip"
  unzip -q "$WORK/gradle.zip" -d "$WORK"
fi

echo "sdk.dir=$ANDROID_HOME" > local.properties

# 4) Build
echo ">> Building..."
"$WORK/gradle-$GRADLE_VER/bin/gradle" --no-daemon assembleDebug
cp app/build/outputs/apk/debug/app-debug.apk ./LeedsLauncher.apk
echo
echo "Done: $(pwd)/LeedsLauncher.apk"

# 5) Optional install on the Firestick
if [ "${1:-}" != "" ]; then
  ADB="$ANDROID_HOME/platform-tools/adb"
  echo ">> Installing on $1 (accept the prompt on the TV if it appears)..."
  "$ADB" connect "$1:5555"
  "$ADB" install -r ./LeedsLauncher.apk
  echo "Installed. Find Leeds Launcher under Your Apps & Channels."
else
  echo "To install: ./build.sh <firestick-ip>   (ADB debugging must be on)"
fi
