cmake_minimum_required(VERSION 3.19)
project(krkr2platform LANGUAGES CXX)

if (BUILD_AS_LIBRARY)
    add_library(${PROJECT_NAME} STATIC
        environ_headless/krkr2_api_impl.cpp
    )
else()
    add_library(${PROJECT_NAME} STATIC
        environ_legacy/sdl/SDLWindow.cpp
        environ_legacy/sdl/SDLRenderer.cpp
        environ_legacy/sdl/SDLInput.cpp
        environ_legacy/sdl/TVPWindow_SDL.cpp
    )
    find_package(SDL3 CONFIG REQUIRED)
    target_link_libraries(${PROJECT_NAME} PRIVATE SDL3::SDL3)
endif()

target_include_directories(${PROJECT_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
    ${CMAKE_CURRENT_SOURCE_DIR}/../core
)

target_link_libraries(${PROJECT_NAME} PUBLIC
    krkr2core
    krkr2-image
    krkr2-archive
    krkr2-crypto
    krkr2-fft
    krkr2-encoding
)

if (APPLE AND BUILD_AS_LIBRARY)
    target_link_libraries(${PROJECT_NAME} PUBLIC
        xml2
        iconv
    )
endif()
