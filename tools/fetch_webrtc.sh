#!/bin/sh
# Downloads Godot's WebRTC extension (webrtc-native, MIT; bundles libdatachannel/libjuice under
# MPL-2.0, usrsctp/libsrtp BSD, mbedtls Apache-2.0) into game/webrtc/, keeping only the builds
# RIPPLE ships: Quest (Android arm64) and desktop Linux/Windows x86_64. Online co-op needs it.
#   sh tools/fetch_webrtc.sh
set -e
VERSION=1.1.1-stable
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/webrtc.zip" "https://github.com/godotengine/webrtc-native/releases/download/$VERSION/godot-extension-webrtc.zip"
unzip -q "$tmp/webrtc.zip" -d "$tmp"
rm -rf game/webrtc && mkdir -p game/webrtc/lib
cp "$tmp"/webrtc/LICENSE.* game/webrtc/
for p in android.template_debug.arm64.so android.template_release.arm64.so \
         linux.template_debug.x86_64.so linux.template_release.x86_64.so \
         windows.template_debug.x86_64.dll windows.template_release.x86_64.dll; do
	cp "$tmp/webrtc/lib/libwebrtc_native.$p" game/webrtc/lib/
done
cat > game/webrtc/webrtc.gdextension <<'GDE'
[configuration]

entry_symbol = "webrtc_extension_init"
compatibility_minimum = 4.1

[libraries]

linux.debug.x86_64 = "lib/libwebrtc_native.linux.template_debug.x86_64.so"
linux.release.x86_64 = "lib/libwebrtc_native.linux.template_release.x86_64.so"
windows.debug.x86_64 = "lib/libwebrtc_native.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "lib/libwebrtc_native.windows.template_release.x86_64.dll"
android.debug.arm64 = "lib/libwebrtc_native.android.template_debug.arm64.so"
android.release.arm64 = "lib/libwebrtc_native.android.template_release.arm64.so"
GDE
rm -rf "$tmp"
echo "webrtc-native $VERSION -> game/webrtc"
