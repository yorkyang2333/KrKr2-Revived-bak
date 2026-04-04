cmake_minimum_required(VERSION 3.19)
project(krkr2platform LANGUAGES CXX)

add_library(${PROJECT_NAME} STATIC
    environ_legacy/sdl/SDLWindow.cpp
    environ_legacy/sdl/SDLRenderer.cpp
    environ_legacy/sdl/SDLInput.cpp
    environ_legacy/sdl/TVPWindow_SDL.cpp
)

target_include_directories(${PROJECT_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
    ${CMAKE_CURRENT_SOURCE_DIR}/../core
)

target_link_libraries(${PROJECT_NAME} PUBLIC
    krkr2core
)

find_package(SDL3 CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE SDL3::SDL3)
