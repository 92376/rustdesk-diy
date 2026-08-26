#!/bin/bash

set -e -o pipefail

ANDROID_ABI=$1

# Build RustDesk dependencies for Android using vcpkg.json
# Required:
#   1. set VCPKG_ROOT / ANDROID_NDK path environment variables
#   2. vcpkg initialized
#   3. ndk, version: r25c or newer

if [ -z "$ANDROID_NDK_HOME" ]; then
  echo "Failed! Please set ANDROID_NDK_HOME"
  exit 1
fi

if [ -z "$VCPKG_ROOT" ]; then
  echo "Failed! Please set VCPKG_ROOT"
  exit 1
fi

API_LEVEL="22"

# Get directory of this script

SCRIPTDIR="$(readlink -f "$0")"
SCRIPTDIR="$(dirname "$SCRIPTDIR")"

# Check if vcpkg.json is one level up - in root directory of RD

if [ ! -f "$SCRIPTDIR/../vcpkg.json" ]; then
  echo "Failed! Please check where vcpkg.json is!"
  exit 1
fi

# NDK llvm toolchain

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) HOST_TAG="windows-x86_64" ;;
  Linux*) HOST_TAG="linux-x86_64" ;;
  Darwin*)
    if [ "$(uname -m)" = "arm64" ]; then
      HOST_TAG="darwin-arm64"
    else
      HOST_TAG="darwin-x86_64"
    fi
    ;;
  *)
    echo "Failed! Unsupported NDK host: $(uname -s)" >&2
    exit 1
    ;;
esac

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG"
if [ ! -d "$TOOLCHAIN" ]; then
  echo "Failed! Android NDK toolchain not found: $TOOLCHAIN" >&2
  exit 1
fi

VCPKG_COMMAND="$VCPKG_ROOT/vcpkg"
if [ ! -x "$VCPKG_COMMAND" ] && [ -x "$VCPKG_ROOT/vcpkg.exe" ]; then
  VCPKG_COMMAND="$VCPKG_ROOT/vcpkg.exe"
fi
if [ ! -x "$VCPKG_COMMAND" ]; then
  echo "Failed! vcpkg executable not found under $VCPKG_ROOT" >&2
  exit 1
fi

echo "Using Android NDK host: $HOST_TAG"

function build {
  ANDROID_ABI=$1

  case "$ANDROID_ABI" in
  arm64-v8a)
     ABI=aarch64-linux-android$API_LEVEL
     VCPKG_TARGET=arm64-android
     ;;
  armeabi-v7a)
     ABI=armv7a-linux-androideabi$API_LEVEL
     VCPKG_TARGET=arm-neon-android
     ;;
  x86_64)
     ABI=x86_64-linux-android$API_LEVEL
     VCPKG_TARGET=x64-android
     ;;
  x86)
     ABI=i686-linux-android$API_LEVEL
     VCPKG_TARGET=x86-android
     ;;
  *)
     echo "ERROR: ANDROID_ABI must be one of: arm64-v8a, armeabi-v7a, x86_64, x86" >&2
     return 1
  esac

  echo "*** [$ANDROID_ABI][Start] Build and install vcpkg dependencies"
  pushd "$SCRIPTDIR/.."
  "$VCPKG_COMMAND" install \
    --triplet "$VCPKG_TARGET" \
    --overlay-triplets="$SCRIPTDIR/../res/vcpkg/triplets" \
    --x-install-root="$VCPKG_ROOT/installed"
  popd
  head -n 100 "${VCPKG_ROOT}/buildtrees/ffmpeg/build-$VCPKG_TARGET-rel-out.log" || true
  echo "*** [$ANDROID_ABI][Finished] Build and install vcpkg dependencies"

if [ -d "$VCPKG_ROOT/installed/arm-neon-android" ]; then
  echo "*** [Start] Move arm-neon-android to arm-android"

  mv "$VCPKG_ROOT/installed/arm-neon-android" "$VCPKG_ROOT/installed/arm-android"

  echo "*** [Finished] Move arm-neon-android to arm-android"
fi
}

if [ ! -z "$ANDROID_ABI" ]; then
  build "$ANDROID_ABI"
else
  echo "Usage: build-android-deps.sh <ANDROID-ABI>" >&2
  exit 1
fi
