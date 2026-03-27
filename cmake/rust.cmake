# cmake/rust.cmake
# =================
# Integrate Rust crates into the CMake build using Corrosion.
# https://github.com/corrosion-rs/corrosion

include(FetchContent)

FetchContent_Declare(
    Corrosion
    GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
    GIT_TAG        v0.5.1
)

FetchContent_MakeAvailable(Corrosion)
