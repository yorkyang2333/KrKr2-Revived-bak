cmake_minimum_required(VERSION 3.19)
project(core_base_module LANGUAGES CXX)

set(BASE_PATH ${CMAKE_CURRENT_LIST_DIR})
set(BASE_SOURCE_FILES
    ${BASE_PATH}/7zArchive.cpp
    ${BASE_PATH}/BinaryStream.cpp
    # CharacterSet.cpp → replaced by Rust krkr2-encoding crate
    ${BASE_PATH}/EventIntf.cpp
    ${BASE_PATH}/ScriptMgnIntf.cpp
    ${BASE_PATH}/StorageIntf.cpp
    ${BASE_PATH}/SysInitIntf.cpp
    ${BASE_PATH}/SystemIntf.cpp
    ${BASE_PATH}/TARArchive.cpp
    ${BASE_PATH}/TextStream.cpp
    ${BASE_PATH}/UtilStreams.cpp
    ${BASE_PATH}/XP3CryptoRegistry.cpp
    ${BASE_PATH}/ZIPArchive.cpp
    ${BASE_PATH}/KAGParser.cpp
    ${BASE_PATH}/MsgIntf.cpp
    ${BASE_PATH}/impl/EventImpl.cpp
    ${BASE_PATH}/impl/StorageImpl.cpp
    ${BASE_PATH}/impl/SysInitImpl.cpp
    ${BASE_PATH}/impl/NativeEventQueue.cpp
    ${BASE_PATH}/impl/SystemImpl.cpp
)

set(BASE_HEADERS_DIR
        ${BASE_PATH}/
        ${BASE_PATH}/impl
        ${BASE_PATH}/../visual
        ${BASE_PATH}/../environ
        ${BASE_PATH}/../sound
        ${BASE_PATH}/../plugin
        ${BASE_PATH}/../movie
        ${BASE_PATH}/../extension
)

add_library(${PROJECT_NAME} STATIC ${BASE_SOURCE_FILES})
target_include_directories(${PROJECT_NAME} PUBLIC
    ${BASE_HEADERS_DIR}
    ${KRKR2_ENCODING_INCLUDE_DIR}
)

if(BUILD_AS_LIBRARY)
    target_include_directories(${PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../../platform/environ_headless
        ${CMAKE_CURRENT_SOURCE_DIR}/../../platform/legacy_cocos2d/visual/impl
    )
endif()

find_package(minizip-ng CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE MINIZIP::minizip-ng)
target_link_libraries(${PROJECT_NAME} PUBLIC tjs2 PRIVATE core_utils_module krkr2-encoding krkr2_archive_adapter)

find_package(uchardet CONFIG REQUIRED)
find_package(unrar CONFIG REQUIRED)
find_package(LibArchive REQUIRED)
find_package(SDL2 CONFIG REQUIRED)
find_package(zstd CONFIG REQUIRED)

target_link_libraries(${PROJECT_NAME} PRIVATE
    uchardet::libuchardet
    unrar::unrar
    LibArchive::LibArchive
    zstd::libzstd

    $<TARGET_NAME_IF_EXISTS:SDL2::SDL2main>
    $<IF:$<TARGET_EXISTS:SDL2::SDL2>,SDL2::SDL2,SDL2::SDL2-static>
)
