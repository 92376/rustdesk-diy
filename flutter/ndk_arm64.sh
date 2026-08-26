#!/usr/bin/env bash

ndk_root="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_HOME:-}}}"
if [ -z "${ndk_root}" ]; then
  echo "ANDROID_NDK_HOME, ANDROID_NDK_ROOT, or NDK_HOME is required" >&2
  exit 1
fi

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    ndk_host="windows-x86_64"
    : "${VCPKG_ROOT:?VCPKG_ROOT is required for Windows-hosted Android builds}"
    export SODIUM_LIB_DIR="${VCPKG_ROOT}/installed/arm64-android/lib"
    sodium_archive="${SODIUM_LIB_DIR}/libsodium.a"
    sodium_compat_archive="${SODIUM_LIB_DIR}/liblibsodium.a"
    if [ ! -f "${sodium_archive}" ]; then
      echo "Missing Android libsodium archive: ${sodium_archive}" >&2
      exit 1
    fi
    cp -f "${sodium_archive}" "${sodium_compat_archive}"
    ;;
  Darwin*)
    ndk_host="darwin-x86_64"
    ;;
  Linux*)
    ndk_host="linux-x86_64"
    ;;
  *)
    echo "Unsupported Android build host: $(uname -s)" >&2
    exit 1
    ;;
esac

: "${VCPKG_ROOT:?VCPKG_ROOT is required for Android builds}"
openssl_dir="${VCPKG_ROOT}/installed/arm64-android"
if [ ! -f "${openssl_dir}/lib/libssl.a" ] || [ ! -f "${openssl_dir}/lib/libcrypto.a" ]; then
  echo "Missing Android OpenSSL libraries under ${openssl_dir}" >&2
  exit 1
fi
export AARCH64_LINUX_ANDROID_OPENSSL_DIR="${openssl_dir}"
export AARCH64_LINUX_ANDROID_OPENSSL_STATIC=1
export AARCH64_LINUX_ANDROID_OPENSSL_NO_VENDOR=1
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="--target=aarch64-linux-android22 --sysroot=${ndk_root}/toolchains/llvm/prebuilt/${ndk_host}/sysroot"

cargo ndk --platform 22 --target aarch64-linux-android build --lib --locked --release --features flutter,hwcodec
