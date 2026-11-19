#!/usr/bin/env bash
set -euo pipefail

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:?An Android SDK is required}}"
adb="$sdk_root/platform-tools/adb"
emulator="$sdk_root/emulator/emulator"
cmdline_tools="$sdk_root/cmdline-tools/latest/bin"
image='system-images;android-35;google_apis;x86_64'
serial='emulator-5554'
avd='transcriber-ci'

hosted_runner() {
  [[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted ]]
}

prepare_host_graphics() {
  local package
  local -a missing=()
  command -v xvfb-run >/dev/null || missing+=(xvfb)
  command -v xauth >/dev/null || missing+=(xauth)
  command -v glxinfo >/dev/null || missing+=(mesa-utils)
  for package in libgl1-mesa-dri libglx-mesa0; do
    if [[ $(dpkg-query --show --showformat='${db:Status-Status}' "$package" 2>/dev/null) != installed ]]; then
      missing+=("$package")
    fi
  done
  if (( ${#missing[@]} )); then
    sudo apt-get -o Acquire::Retries=2 update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=2 \
      install --yes --no-install-recommends "${missing[@]}"
  fi
}

test -c /dev/kvm
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  if ! hosted_runner; then
    echo "The local user needs read and write access to /dev/kvm." >&2
    exit 1
  fi
  sudo chmod a+rw /dev/kvm
fi
if [[ ! -x "$adb" || ! -x "$cmdline_tools/avdmanager" ]]; then
  echo "The Android SDK needs platform-tools and the latest command-line tools." >&2
  exit 1
fi
export PATH="$sdk_root/platform-tools:$PATH"
if ! "$adb" devices | awk 'NR > 1 && NF { exit 1 }'; then
  echo "The Android device runner needs an isolated ADB session." >&2
  exit 1
fi

packages=()
if [[ ! -x "$emulator" ]]; then
  packages+=('emulator')
fi
if [[ ! -f "$sdk_root/system-images/android-35/google_apis/x86_64/package.xml" ]]; then
  packages+=("$image")
fi
if (( ${#packages[@]} )); then
  if ! hosted_runner || [[ ! -x "$cmdline_tools/sdkmanager" ]]; then
    echo "Missing Android SDK packages: ${packages[*]}" >&2
    exit 1
  fi
  "$cmdline_tools/sdkmanager" --sdk_root="$sdk_root" "${packages[@]}"
fi
"$emulator" -accel-check
"$emulator" -version | awk 'NR == 1'
if hosted_runner; then
  prepare_host_graphics
fi

ANDROID_AVD_HOME=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/transcriber-avd.XXXXXX")
export ANDROID_AVD_HOME
emulator_pid=''
cleanup() {
  if [[ -n "$emulator_pid" ]]; then
    timeout 10 "$adb" -s "$serial" emu kill >/dev/null 2>&1 || kill "$emulator_pid" 2>/dev/null || true
  fi
  rm -rf -- "$ANDROID_AVD_HOME"
}
trap cleanup EXIT

report_device_failure() {
  df -hP "$ANDROID_AVD_HOME" "$sdk_root" | awk '
    NR == 2 { print "Free space in the AVD workspace: " $4 }
    NR == 3 { print "Free space in the Android SDK: " $4 }
  ' >&2 || true
  LC_ALL=C awk -v home="${HOME:-}" -v host="${HOSTNAME:-}" '
    {
      lower = tolower($0)
      if (lower !~ /error|fatal|failed|segmentation|missing|not enough|no space|permission denied|display|xauth|xcb|glx/) next
      if (lower ~ /key|authenticat|@/ || (home != "" && index($0, home)) || (host != "" && index($0, host))) next
      gsub(/[[:cntrl:]]/, "")
      printf "Emulator: %.300s\n", $0
    }
  ' "$@" | tail -20 >&2 || true
}

export LIBGL_ALWAYS_SOFTWARE=1
graphics_log="$ANDROID_AVD_HOME/graphics.log"
graphics_xvfb_log="$ANDROID_AVD_HOME/graphics-xvfb.log"
emulator_log="$ANDROID_AVD_HOME/emulator.log"
emulator_xvfb_log="$ANDROID_AVD_HOME/emulator-xvfb.log"
: > "$graphics_xvfb_log"
: > "$emulator_xvfb_log"
if ! timeout 20 xvfb-run --auto-servernum --error-file "$graphics_xvfb_log" glxinfo -B > "$graphics_log" 2>&1 ||
  ! awk '/^OpenGL renderer string:.*(llvmpipe|softpipe)/ { print; found = 1 } END { exit !found }' "$graphics_log"; then
  echo "Xvfb did not provide a Mesa software GLX renderer." >&2
  report_device_failure "$graphics_log" "$graphics_xvfb_log"
  exit 1
fi

printf 'no\n' | "$cmdline_tools/avdmanager" create avd --name "$avd" --package "$image"
xvfb-run --auto-servernum --error-file "$emulator_xvfb_log" "$emulator" \
  -avd "$avd" -port 5554 -no-audio -no-snapshot -no-boot-anim \
  -gpu host -feature -Vulkan -accel on > "$emulator_log" 2>&1 &
emulator_pid=$!
deadline=$((SECONDS + 180))
while :; do
  if readiness=$(timeout 5 "$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null) && [[ "$readiness" == 1 ]]; then
    break
  fi
  if (( SECONDS >= deadline )) || ! kill -0 "$emulator_pid" 2>/dev/null; then
    echo "The Android test device did not finish booting." >&2
    report_device_failure "$emulator_log" "$emulator_xvfb_log"
    exit 1
  fi
  sleep 2
done

abi_list=$("$adb" -s "$serial" shell getprop ro.product.cpu.abilist)
if [[ ",$abi_list," != *,arm64-v8a,* ]]; then
  echo "The Android test device must support the arm64-v8a APK." >&2
  exit 1
fi
"$adb" -s "$serial" shell wm dismiss-keyguard
"$adb" -s "$serial" shell cmd connectivity airplane-mode enable
"$adb" -s "$serial" shell svc wifi disable
android/gradlew -p android :app:connectedDebugAndroidTest || {
  status=$?
  report_device_failure "$emulator_log" "$emulator_xvfb_log"
  exit "$status"
}

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
  node --test test/tool/ci/android-picker-device.integration.cjs || {
  status=$?
  report_device_failure "$emulator_log" "$emulator_xvfb_log"
  exit "$status"
}
