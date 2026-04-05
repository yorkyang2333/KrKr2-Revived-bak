cmake_minimum_required(VERSION 3.19)
project(core_visual_module LANGUAGES CXX)

set(VISUAL_PATH ${CMAKE_CURRENT_LIST_DIR})
set(VISUAL_SOURCE_FILES
    ${VISUAL_PATH}/LoadWEBP.cpp
    ${VISUAL_PATH}/TransIntf.cpp
    ${VISUAL_PATH}/MenuItemIntf.cpp
    ${VISUAL_PATH}/SaveTLG5.cpp
    ${VISUAL_PATH}/FontSystem.cpp
    ${VISUAL_PATH}/tvpps.inc
#     ${VISUAL_PATH}/LoadPVRv3.cpp
    ${VISUAL_PATH}/RectItf.cpp
    ${VISUAL_PATH}/VideoOvlIntf.cpp
    ${VISUAL_PATH}/LayerBitmapIntf.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../platform/legacy_cocos2d/visual/impl/LayerBitmapImpl.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../platform/legacy_cocos2d/visual/impl/DrawDevice.cpp
    ${VISUAL_PATH}/FontImpl.cpp
#     ${VISUAL_PATH}/RenderManager.cpp
    ${VISUAL_PATH}/LoadJPEG.cpp
    ${VISUAL_PATH}/GraphicsLoaderIntf.cpp
    ${VISUAL_PATH}/SaveTLG6.cpp
    ${VISUAL_PATH}/FreeType.cpp
#     ${VISUAL_PATH}/LoadJXR.cpp
    ${VISUAL_PATH}/ImageFunction.cpp
    ${VISUAL_PATH}/tvpgl.cpp
    ${VISUAL_PATH}/LoadTLGHeader.cpp
    ${VISUAL_PATH}/LayerTreeOwnerImpl.cpp
    ${VISUAL_PATH}/BitmapBitsAlloc.cpp
    ${VISUAL_PATH}/GraphicsLoadThread.cpp
    ${VISUAL_PATH}/LayerManager.cpp
    ${VISUAL_PATH}/PrerenderedFont.cpp
#     ${VISUAL_PATH}/LoadBPG.cpp
    ${VISUAL_PATH}/WindowIntf.cpp
    ${VISUAL_PATH}/WindowImpl.cpp
    ${VISUAL_PATH}/TVPScreen.cpp
    ${VISUAL_PATH}/FreeTypeFontRasterizer.cpp
    ${VISUAL_PATH}/LoadPNG.cpp
    ${VISUAL_PATH}/LayerIntf.cpp
    ${VISUAL_PATH}/ComplexRect.cpp
    ${VISUAL_PATH}/CharacterData.cpp
    ${VISUAL_PATH}/BitmapLayerTreeOwner.cpp
    ${VISUAL_PATH}/BitmapIntf.cpp
    ${VISUAL_PATH}/argb.cpp
    ${VISUAL_PATH}/BitmapInfomation.cpp

    ${VISUAL_PATH}/gl/blend_function.cpp
    ${VISUAL_PATH}/gl/ResampleImage.cpp
    ${VISUAL_PATH}/gl/WeightFunctor.cpp

)

set(VISUAL_HEADERS_DIR
    ${VISUAL_PATH}/
    ${VISUAL_PATH}/gl
    ${VISUAL_PATH}/ogl
    ${VISUAL_PATH}/impl
)

add_library(${PROJECT_NAME} STATIC ${VISUAL_SOURCE_FILES})
target_include_directories(${PROJECT_NAME} PUBLIC ${VISUAL_HEADERS_DIR})
target_link_libraries(${PROJECT_NAME} PUBLIC tjs2 PRIVATE core_base_module core_utils_module)

# Rust TLG decoder (krkr2-image crate) + C++ adapter
if(TARGET krkr2_image_adapter)
    target_link_libraries(${PROJECT_NAME} PRIVATE krkr2_image_adapter)
    target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../../rust/krkr2-image/include)
endif()

find_package(Freetype REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE Freetype::Freetype)

# target_link_libraries(${PROJECT_NAME} PRIVATE libbpg)

find_package(WebP CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} INTERFACE WebP::webp WebP::webpdecoder WebP::webpdemux)


# find_package(JXR REQUIRED)
target_compile_definitions(${PROJECT_NAME} PRIVATE -D__ANSI__)
# target_include_directories(${PROJECT_NAME} PRIVATE ${JXR_INCLUDE_DIRS})
# target_link_libraries(${PROJECT_NAME} PRIVATE ${JXR_LIBRARIES})

find_package(libjpeg-turbo CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PUBLIC
    $<IF:$<TARGET_EXISTS:libjpeg-turbo::turbojpeg>,libjpeg-turbo::turbojpeg,libjpeg-turbo::turbojpeg-static>
)

set(OpenCV_ROOT "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/share/opencv4")
find_package(OpenCV REQUIRED)
target_link_libraries(${PROJECT_NAME} PUBLIC
    opencv_imgproc
    opencv_core
)

find_package(lz4 CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PUBLIC
    lz4::lz4
)
