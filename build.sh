#!/bin/bash
#
# Builds Clock and Calendar by Dhaval into a runnable .app bundle.
#
#   ./build.sh              build only          -> dist/Clock and Calendar by Dhaval.app
#   ./build.sh --install    build + copy to /Applications + relaunch
#   ./build.sh --run        build + run from dist
#   ./build.sh --install --login   also start it at every login
#   ./build.sh --unlogin    remove the login item
#   ./build.sh --zip        build + zip for a GitHub release -> dist/ClockAndCalendar-<version>.zip
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Clock and Calendar by Dhaval"
BINARY="ClockAndCalendar"
BUNDLE_ID="com.dhaval.clockandcalendar"
DIST="dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

INSTALL=0
RUN=0
LOGIN=0
ZIP=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --run) RUN=1 ;;
    --login) LOGIN=1 ;;
    --zip) ZIP=1 ;;
    --unlogin)
      launchctl bootout "gui/$UID/$BUNDLE_ID" 2>/dev/null || true
      rm -f "$AGENT"
      echo "==> Login item removed"
      exit 0
      ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# Universal (Apple silicon + Intel) when the toolchain can do it in one step,
# otherwise just this Mac's architecture.
echo "==> Compiling (release, universal)"
ARCH_FLAGS=(--arch arm64 --arch x86_64)
if ! swift build -c release "${ARCH_FLAGS[@]}"; then
  echo "    universal build failed, building for this Mac only"
  ARCH_FLAGS=()
  swift build -c release
fi
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"
echo "    architectures: $(lipo -archs "$BIN_DIR/$BINARY")"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/$BINARY" "$CONTENTS/MacOS/$BINARY"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Rendering icon"
ICON_BUILD="$DIST/icon.build"
rm -rf "$ICON_BUILD"
mkdir -p "$ICON_BUILD/AppIcon.iconset"
if swift tools/make-icon.swift "$ICON_BUILD/icon.png" >/dev/null 2>&1; then
  for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size "$ICON_BUILD/icon.png" \
      --out "$ICON_BUILD/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  done
  # Retina variants are the next size up, renamed.
  for pair in "16 32" "32 64" "128 256" "256 512" "512 1024"; do
    set -- $pair
    cp "$ICON_BUILD/AppIcon.iconset/icon_$2x$2.png" \
       "$ICON_BUILD/AppIcon.iconset/icon_$1x$1@2x.png"
  done
  rm -f "$ICON_BUILD/AppIcon.iconset/icon_64x64.png" \
        "$ICON_BUILD/AppIcon.iconset/icon_1024x1024.png"
  iconutil -c icns "$ICON_BUILD/AppIcon.iconset" -o "$CONTENTS/Resources/AppIcon.icns"
  echo "    icon embedded"
else
  echo "    icon render skipped (app still works, just no custom icon)"
fi
rm -rf "$ICON_BUILD"

# Ad-hoc signature. No Apple ID, no certificate, no notarisation: this is all
# macOS needs for an app you built yourself on this machine.
echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/    /'

echo "==> Built $APP"

if [[ $ZIP -eq 1 ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
  ZIP_PATH="$DIST/$BINARY-$VERSION.zip"
  rm -f "$ZIP_PATH"
  # ditto, not zip: it keeps the code signature intact.
  ditto -c -k --keepParent "$APP" "$ZIP_PATH"
  echo "==> Zipped $ZIP_PATH"
fi

if [[ $INSTALL -eq 1 ]]; then
  echo "==> Installing to /Applications"
  pkill -x "$BINARY" 2>/dev/null || true
  sleep 0.5
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
  # Locally built apps are never quarantined, but clear it defensively.
  xattr -dr com.apple.quarantine "/Applications/$APP_NAME.app" 2>/dev/null || true
  # Leaving a second bundle in dist makes the app show up twice in Spotlight
  # and Launchpad.
  rm -rf "$APP"
  open "/Applications/$APP_NAME.app"
  echo "==> Running from /Applications — look for the calendar-clock icon in your menu bar"
elif [[ $RUN -eq 1 ]]; then
  pkill -x "$BINARY" 2>/dev/null || true
  sleep 0.5
  open "$APP"
  echo "==> Running from $APP — look for the calendar-clock icon in your menu bar"
fi

if [[ $LOGIN -eq 1 ]]; then
  if [[ $INSTALL -ne 1 && ! -d "/Applications/$APP_NAME.app" ]]; then
    echo "!! --login needs the app in /Applications; run: ./build.sh --install --login" >&2
    exit 1
  fi
  echo "==> Registering login item"
  # A plain LaunchAgent needs no entitlements and no developer account.
  mkdir -p "$(dirname "$AGENT")"
  cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$BUNDLE_ID</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Applications/$APP_NAME.app/Contents/MacOS/$BINARY</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$UID/$BUNDLE_ID" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$AGENT"
  echo "    starts automatically at login (remove with ./build.sh --unlogin)"
fi
