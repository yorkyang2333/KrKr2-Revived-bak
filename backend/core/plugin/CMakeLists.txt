cmake_minimum_required(VERSION 3.19)
project(core_plugin_module LANGUAGES CXX)

set(PLUGIN_PATH ${CMAKE_CURRENT_LIST_DIR})
set(PLUGIN_SOURCE_FILES
        ${PLUGIN_PATH}/ncbind.cpp
        ${PLUGIN_PATH}/PluginIntf.cpp
        ${PLUGIN_PATH}/PluginImpl.cpp
)

set(PLUGIN_HEADERS_DIR
        ${PLUGIN_PATH}/
)

add_library(${PROJECT_NAME} STATIC ${PLUGIN_SOURCE_FILES})
target_include_directories(${PROJECT_NAME} PUBLIC ${PLUGIN_HEADERS_DIR})
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../../rust/krkr2-crypto/include
)
target_link_libraries(${PROJECT_NAME} PUBLIC tjs2 PRIVATE core_base_module core_visual_module core_utils_module krkr2-crypto)
