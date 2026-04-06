#!/usr/bin/env bash
# build_all.sh - Interactive One-click build script for KrKr2-Revived

set -euo pipefail

read_with_default() {
    local prompt="$1"
    local default_value="$2"
    local result_var="$3"
    local value=""

    if [ -t 0 ]; then
        read -r -p "$prompt" value
    else
        value="$default_value"
        echo "$prompt$value"
    fi

    printf -v "$result_var" '%s' "$value"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

find_latest_file() {
    local search_root="$1"
    local pattern="$2"

    find "$search_root" -type f -name "$pattern" -exec stat -f '%m %N' {} + 2>/dev/null \
        | sort -nr \
        | head -n 1 \
        | cut -d' ' -f2-
}

directory_is_empty() {
    local dir="$1"
    [ -d "$dir" ] && [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]
}

is_vcpkg_layout() {
    local dir="$1"
    [ -f "$dir/bootstrap-vcpkg.sh" ] || \
    [ -f "$dir/bootstrap-vcpkg.bat" ] || \
    [ -f "$dir/scripts/buildsystems/vcpkg.cmake" ] || \
    [ -x "$dir/vcpkg" ]
}

ensure_command() {
    local cmd="$1"
    local hint="${2:-}"

    if ! command_exists "$cmd"; then
        echo "❌ Required command not found: $cmd"
        if [ -n "$hint" ]; then
            echo "   $hint"
        fi
        exit 1
    fi
}

bootstrap_vcpkg() {
    local vcpkg_root="$1"
    local bootstrap_script=""

    if [ -x "$vcpkg_root/vcpkg" ]; then
        return 0
    fi

    if [ -f "$vcpkg_root/bootstrap-vcpkg.sh" ]; then
        bootstrap_script="$vcpkg_root/bootstrap-vcpkg.sh"
        echo "🔧 Bootstrapping vcpkg..."
        chmod +x "$bootstrap_script"
        "$bootstrap_script" -disableMetrics
        return 0
    fi

    if [ -f "$vcpkg_root/bootstrap-vcpkg.bat" ]; then
        bootstrap_script="$vcpkg_root/bootstrap-vcpkg.bat"
        echo "🔧 Bootstrapping vcpkg..."
        cmd //c "$bootstrap_script" -disableMetrics
        return 0
    fi

    echo "❌ vcpkg bootstrap script not found in $vcpkg_root"
    exit 1
}

prepare_vcpkg() {
    local repo_root="$1"
    local vcpkg_root="$repo_root/vcpkg_root"
    local vcpkg_git_url="https://github.com/microsoft/vcpkg.git"

    if [ ! -e "$vcpkg_root" ]; then
        echo "📥 Cloning vcpkg into $vcpkg_root ..."
        git clone "$vcpkg_git_url" "$vcpkg_root"
    elif directory_is_empty "$vcpkg_root"; then
        echo "📁 Found empty directory at $vcpkg_root, cloning vcpkg into it..."
        git clone "$vcpkg_git_url" "$vcpkg_root"
    elif [ -d "$vcpkg_root/.git" ]; then
        echo "📦 Reusing existing vcpkg git checkout: $vcpkg_root"
    elif is_vcpkg_layout "$vcpkg_root"; then
        echo "📦 Reusing existing vcpkg directory: $vcpkg_root"
    else
        echo "❌ $vcpkg_root exists, but it does not look like a usable vcpkg directory."
        echo "   Please remove it or replace it with a valid vcpkg checkout, then rerun ./build_all.sh"
        exit 1
    fi

    bootstrap_vcpkg "$vcpkg_root"

    export VCPKG_ROOT="$vcpkg_root"
    echo "✅ VCPKG_ROOT is ready: $VCPKG_ROOT"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_command git "Please install Git first."
ensure_command cmake "Please install CMake 3.28 or newer."
ensure_command flutter "Please install Flutter and make sure it is in PATH."

prepare_vcpkg "$ROOT_DIR"

echo "=================================================="
echo "    KrKr2-Revived: Auto-Build Pipeline            "
echo "=================================================="
echo ""
echo "Please select the target platform to build for:"
echo "1) macOS (Apple Silicon / Intel)"
echo "2) Linux (x86_64)"
echo "3) Auto-detect (Current System)"
echo ""
read_with_default "Enter choice [1-3, Default: 3]: " "3" OS_CHOICE

OS_NAME=$(uname -s)

case $OS_CHOICE in
    1)
        BUILD_PLATFORM="macos"
        ;;
    2)
        BUILD_PLATFORM="linux"
        ;;
    *)
        if [ "$OS_NAME" == "Darwin" ]; then
            BUILD_PLATFORM="macos"
        else
            BUILD_PLATFORM="linux"
        fi
        ;;
esac

echo ""
echo "Please select Build Configuration:"
echo "1) Release"
echo "2) Debug"
read_with_default "Enter choice [1-2, Default: 1]: " "1" CONFIG_CHOICE

if [ "$CONFIG_CHOICE" == "2" ]; then
    BUILD_TYPE="Debug"
else
    BUILD_TYPE="Release"
fi

if [ "$BUILD_PLATFORM" == "macos" ]; then
    export PATH="/opt/homebrew/opt/bison/bin:$PATH"
    PRESET_CONFIG="MacOS ${BUILD_TYPE} Config"
    PRESET_BUILD="MacOS ${BUILD_TYPE} Build"
else
    PRESET_CONFIG="Linux ${BUILD_TYPE} Config"
    PRESET_BUILD="Linux ${BUILD_TYPE} Build"
fi

echo ""
echo "🚀 [Step 1/2]: Building C++ / Rust Backend Engine ($PRESET_BUILD)..."
echo "--------------------------------------------------"
cmake --preset="$PRESET_CONFIG" -DBUILD_AS_LIBRARY=ON

echo "✅ CMake Configured! Compiling krkr2platform and repo-backed plugins..."
cmake --build --preset="$PRESET_BUILD" --target krkr2platform krkr2plugins -j$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

if [ "$BUILD_PLATFORM" == "macos" ]; then
    BUILD_TYPE_LOWER=$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')
    BACKEND_PLATFORM_LIB="$ROOT_DIR/out/macos/$BUILD_TYPE_LOWER/backend/platform/libkrkr2platform.a"
    BACKEND_PLUGIN_DIR="$ROOT_DIR/out/macos/$BUILD_TYPE_LOWER/backend/plugins"
    MACOS_PLUGIN_LIBS=(
        libkrkr2plugin.a
        libjson.a
        libfstat.a
        libpsbfile.a
        libpsdparse.a
        libpsdfile.a
        libmotionplayer.a
        libsteam.a
        libDrawDeviceForSteam.a
    )

    echo "🔎 Verifying macOS backend artifacts..."
    if [ ! -f "$BACKEND_PLATFORM_LIB" ]; then
        echo "❌ Missing backend platform library: $BACKEND_PLATFORM_LIB"
        exit 1
    fi

    for plugin_lib in "${MACOS_PLUGIN_LIBS[@]}"; do
        if [ ! -f "$BACKEND_PLUGIN_DIR/$plugin_lib" ]; then
            echo "❌ Missing backend plugin library: $BACKEND_PLUGIN_DIR/$plugin_lib"
            exit 1
        fi
    done
fi

echo "✅ Backend Engine build complete!"
echo ""

echo "📱 [Step 2/2]: Building Flutter Frontend UI ($BUILD_PLATFORM)..."
echo "--------------------------------------------------"

echo "📦 Preparing macOS frontend libraries..."
mkdir -p "$ROOT_DIR/frontend/macos/krkr2_libs"
rm -f "$ROOT_DIR/frontend/macos/krkr2_libs"/*.a

VCPKG_ARCH="arm64-osx"
if [ "$OS_NAME" == "Darwin" ] && [ "$(uname -m)" == "x86_64" ]; then
    VCPKG_ARCH="x86_64-osx"
fi

if [ "$BUILD_PLATFORM" == "macos" ]; then
    RUST_PROFILE_DIR="$ROOT_DIR/backend/rust/target/debug"
    RUST_BUILD_DIR="$RUST_PROFILE_DIR/build"
    echo "📚 Syncing Rust static libraries for Xcode..."
    for rust_lib in \
        libkrkr2_image.a \
        libkrkr2_archive.a \
        libkrkr2_bridge.a \
        libkrkr2_crypto.a \
        libkrkr2_fft.a \
        libkrkr2_encoding.a
    do
        if [ -f "$RUST_PROFILE_DIR/$rust_lib" ]; then
            cp -f "$RUST_PROFILE_DIR/$rust_lib" "$ROOT_DIR/frontend/macos/krkr2_libs/"
        fi
    done

    for bridge_lib in libcxxbridge1.a libkrkr2-image-cxxgen.a libkrkr2-archive-cxxgen.a libkrkr2-bridge-cxxgen.a libkrkr2_audio_cxx.a
    do
        latest_bridge_lib=$(find_latest_file "$RUST_BUILD_DIR" "$bridge_lib")
        if [ -n "${latest_bridge_lib:-}" ] && [ -f "$latest_bridge_lib" ]; then
            cp -f "$latest_bridge_lib" "$ROOT_DIR/frontend/macos/krkr2_libs/"
        fi
    done
fi

cd "$ROOT_DIR/frontend" || { echo "❌ Frontend directory not found!"; exit 1; }

echo "📦 Fetching Flutter dependencies..."
flutter pub get

echo "⚙️ Compiling Flutter Native Application ($BUILD_TYPE)..."
if [ "$BUILD_TYPE" == "Debug" ]; then
    flutter build $BUILD_PLATFORM --debug
else
    flutter build $BUILD_PLATFORM --release
fi

echo ""
echo "🎉 Build Process Completed Successfully! 🎉"
echo "You can find the frontend executable in the corresponding frontend/build/ directory."
echo "=================================================="
