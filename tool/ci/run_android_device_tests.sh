#!/usr/bin/env bash
set -euo pipefail

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:?An Android SDK is required}}"
image='system-images;android-35;google_apis;x86_64'
serial='emulator-5554'
avd='transcriber-ci'

hosted_runner() {
  [[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted ]]
}

test -c /dev/kvm
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  if ! hosted_runner; then
    echo "The local user needs read and write access to /dev/kvm." >&2
    exit 1
  fi
  sudo chmod a+rw /dev/kvm
fi
emulator -accel-check
if ! adb devices | awk 'NR > 1 && NF { exit 1 }'; then
  echo "The Android device runner needs an isolated ADB session." >&2
  exit 1
fi

if [[ ! -f "$sdk_root/system-images/android-35/google_apis/x86_64/package.xml" ]]; then
  if ! hosted_runner; then
    echo "The local Android SDK needs the API 35 Google APIs x86_64 image." >&2
    exit 1
  fi
  sdkmanager --sdk_root="$sdk_root" "$image"
fi

ANDROID_AVD_HOME=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/transcriber-avd.XXXXXX")
export ANDROID_AVD_HOME
emulator_pid=''
cleanup() {
  if [[ -n "$emulator_pid" ]]; then
    timeout 10 adb -s "$serial" emu kill >/dev/null 2>&1 || kill "$emulator_pid" 2>/dev/null || true
  fi
  rm -rf -- "$ANDROID_AVD_HOME"
}
trap cleanup EXIT

printf 'no\n' | avdmanager create avd --name "$avd" --package "$image"
xvfb-run --auto-servernum emulator -avd "$avd" -port 5554 -no-audio -no-snapshot -no-boot-anim \
  -gpu host -feature -Vulkan -accel on > "$ANDROID_AVD_HOME/emulator.log" 2>&1 &
emulator_pid=$!
deadline=$((SECONDS + 180))
while :; do
  if readiness=$(timeout 5 adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null) && [[ "$readiness" == 1 ]]; then
    break
  fi
  if (( SECONDS >= deadline )) || ! kill -0 "$emulator_pid" 2>/dev/null; then
    echo "The Android test device did not finish booting." >&2
    exit 1
  fi
  sleep 2
done

abi_list=$(adb -s "$serial" shell getprop ro.product.cpu.abilist)
if [[ ",$abi_list," != *,arm64-v8a,* ]]; then
  echo "The Android test device must support the arm64-v8a APK." >&2
  exit 1
fi
adb -s "$serial" shell wm dismiss-keyguard
adb -s "$serial" shell cmd connectivity airplane-mode enable
adb -s "$serial" shell svc wifi disable
android/gradlew -p android :app:connectedDebugAndroidTest

apk=''
for candidate in build/app/outputs/apk/debug/app-debug.apk android/app/build/outputs/apk/debug/app-debug.apk; do
  if [[ -s "$candidate" ]]; then
    if [[ -n "$apk" ]]; then
      echo "More than one debug APK was produced by the Android build." >&2
      exit 1
    fi
    apk="$PWD/$candidate"
  fi
done
if [[ -z "$apk" ]]; then
  echo "No debug APK was produced for the Android picker test." >&2
  exit 1
fi
ANDROID_SERIAL="$serial" TRANSCRIBER_TEST_AVD="$avd" TRANSCRIBER_TEST_APK="$apk" \
  node --test test/tool/ci/android-picker-device.integration.cjs
