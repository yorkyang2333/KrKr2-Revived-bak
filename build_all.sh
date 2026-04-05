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

    if [ ! -d "$vcpkg_root/.git" ]; then
        if [ -e "$vcpkg_root" ]; then
            echo "❌ $vcpkg_root already exists, but it is not a valid vcpkg git checkout."
            exit 1
        fi

        echo "📥 Cloning vcpkg into $vcpkg_root ..."
        git clone "$vcpkg_git_url" "$vcpkg_root"
    else
        echo "📦 Reusing existing vcpkg checkout: $vcpkg_root"
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

echo "✅ CMake Configured! Compiling krkr2platform..."
cmake --build --preset="$PRESET_BUILD" --target krkr2platform -j$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
echo "✅ Backend Engine build complete!"
echo ""

echo "📱 [Step 2/2]: Building Flutter Frontend UI ($BUILD_PLATFORM)..."
echo "--------------------------------------------------"

echo "📦 Packing engine backend static libraries..."
mkdir -p "$ROOT_DIR/frontend/macos/krkr2_libs"
rm -f "$ROOT_DIR/frontend/macos/krkr2_libs"/*.a

VCPKG_ARCH="arm64-osx"
if [ "$OS_NAME" == "Darwin" ] && [ "$(uname -m)" == "x86_64" ]; then
    VCPKG_ARCH="x86_64-osx"
fi

if [ "$BUILD_PLATFORM" == "macos" ]; then
    BUILD_TYPE_LOWER=$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')
    BACKEND_LIBS=$(find "$ROOT_DIR/out/macos/$BUILD_TYPE_LOWER/backend" -name "*.a" 2>/dev/null)
    VCPKG_LIBS=$(find "$ROOT_DIR/out/macos/$BUILD_TYPE_LOWER/vcpkg_installed/$VCPKG_ARCH/lib" -name "*.a" 2>/dev/null)
    # Rust crate outputs (Corrosion builds them into backend/rust/target/)
    # Use release build if available, fall back to debug (Corrosion defaults to debug)
    RUST_TARGET_DIR="$ROOT_DIR/backend/rust/target"
    if [ "$BUILD_TYPE_LOWER" == "release" ] && [ -d "$RUST_TARGET_DIR/aarch64-apple-darwin/release" ]; then
        RUST_PROFILE_DIR="$RUST_TARGET_DIR/aarch64-apple-darwin/release"
    elif [ "$BUILD_TYPE_LOWER" == "release" ] && [ -d "$RUST_TARGET_DIR/release" ]; then
        RUST_PROFILE_DIR="$RUST_TARGET_DIR/release"
    else
        RUST_PROFILE_DIR="$RUST_TARGET_DIR/debug"
    fi
    # Top-level crate .a files (exclude noisy deps/ duplicates)
    RUST_LIBS=$(find "$RUST_PROFILE_DIR" -maxdepth 1 -name "libkrkr2*.a" 2>/dev/null)
    # cxx bridge runtime (libcxxbridge1.a, libkrkr2-*-cxxgen.a, etc.)
    CXX_BRIDGE_LIBS=$(find "$RUST_TARGET_DIR/debug/build" -name "libcxxbridge1.a" -o -name "libkrkr2-*-cxxgen.a" -o -name "libkrkr2_*_cxx.a" 2>/dev/null | head -20)
    if [ -z "$BACKEND_LIBS" ]; then
        echo "❌ No backend .a files found in out/macos/$BUILD_TYPE_LOWER/backend. Did the C++ build succeed?"
        exit 1
    fi
    echo "  → Backend C++ libs: $(echo $BACKEND_LIBS | wc -w | tr -d ' ') files"
    echo "  → Rust crate libs: $(echo $RUST_LIBS | wc -w | tr -d ' ') files from $RUST_PROFILE_DIR"
    echo "  → cxx bridge libs: $(echo $CXX_BRIDGE_LIBS | wc -w | tr -d ' ') files"
    libtool -static -o "$ROOT_DIR/frontend/macos/krkr2_libs/libkrkr2_backend.a" \
        $BACKEND_LIBS $RUST_LIBS $CXX_BRIDGE_LIBS $VCPKG_LIBS
    echo "✅ libkrkr2_backend.a packed ($(du -sh "$ROOT_DIR/frontend/macos/krkr2_libs/libkrkr2_backend.a" | cut -f1))"
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
