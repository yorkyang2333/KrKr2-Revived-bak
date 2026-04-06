cmake_minimum_required(VERSION 3.19)
project(krkr2plugin)

add_library(${PROJECT_NAME} STATIC)

target_sources(${PROJECT_NAME} PRIVATE
    scriptsEx.cpp
    win32dialog.cpp
    dirlist.cpp
    csvParser.cpp
    varfile.cpp
    saveStruct.cpp
    getabout.cpp
    addFont.cpp
    windowEx.cpp
    getSample.cpp
    layerExPerspective.cpp
    fftgraph.cpp
    LayerExBase.cpp
    xp3filter.cpp
)

target_include_directories(${PROJECT_NAME} PUBLIC
    ${KRKR2CORE_PATH}/
    ${KRKR2CORE_PATH}/base
    ${KRKR2CORE_PATH}/base/win32
    ${KRKR2CORE_PATH}/environ
    ${KRKR2CORE_PATH}/environ/win32
    ${KRKR2CORE_PATH}/environ/android
    ${KRKR2CORE_PATH}/environ/sdl
    ${KRKR2CORE_PATH}/msg
    ${KRKR2CORE_PATH}/msg/win32
    ${KRKR2CORE_PATH}/extension
    ${KRKR2CORE_PATH}/sound
    ${KRKR2CORE_PATH}/sound/win32
    ${KRKR2CORE_PATH}/tjs2
    ${KRKR2CORE_PATH}/utils
    ${KRKR2CORE_PATH}/utils/win32
    ${KRKR2CORE_PATH}/visual
    ${KRKR2CORE_PATH}/visual/ARM
    ${KRKR2CORE_PATH}/visual/win32
    ${KRKR2CORE_PATH}/visual/RenderScript/rs
)

add_definitions(-D__STDC_CONSTANT_MACROS -DTJS_TEXT_OUT_CRLF)

target_include_directories(${PROJECT_NAME} PUBLIC
    ${KRKR2PLUGIN_PATH}
    ${KRKR2PLUGIN_PATH}/simplebinder
)
target_link_libraries(${PROJECT_NAME} PUBLIC krkr2core)

find_package(fmt CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE fmt::fmt)

find_package(spdlog CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE spdlog::spdlog)

set(KRKR2_PLUGIN_ARCHIVE_DIR "${CMAKE_BINARY_DIR}/backend/plugins")

function(krkr2_configure_plugin_archive target_name)
    set_target_properties(${target_name} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${KRKR2_PLUGIN_ARCHIVE_DIR}"
    )
endfunction()

krkr2_configure_plugin_archive(${PROJECT_NAME})

# Repo-backed plugins that can participate in the current headless macOS build.
# Plugins that still require the disabled movie/sound core modules stay out of
# this bundle until those subsystems are wired back into the backend build.
add_subdirectory(json)
add_subdirectory(fstat)
add_subdirectory(psbfile)
add_subdirectory(psdfile)
add_subdirectory(motionplayer)
add_subdirectory(steam)
add_subdirectory(DrawDeviceForSteam)
add_subdirectory(layerex_draw)

set(KRKR2_REPO_PLUGIN_TARGETS
    ${PROJECT_NAME}
    json
    fstat
    psbfile
    psdparse
    psdfile
    motionplayer
    steam
    DrawDeviceForSteam
)

foreach(plugin_target IN LISTS KRKR2_REPO_PLUGIN_TARGETS)
    krkr2_configure_plugin_archive(${plugin_target})
endforeach()

add_custom_target(krkr2plugins DEPENDS ${KRKR2_REPO_PLUGIN_TARGETS})
