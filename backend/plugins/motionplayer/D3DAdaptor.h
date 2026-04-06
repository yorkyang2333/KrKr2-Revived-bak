#pragma once

#include "tjs.h"

namespace motion {

class D3DAdaptor {
public:
    D3DAdaptor(iTJSDispatch2 *window, tjs_int width, tjs_int height,
               tjs_real halfWidth, tjs_real halfHeight) :
        window_(window), width_(width), height_(height), halfWidth_(halfWidth),
        halfHeight_(halfHeight) {}

    static tjs_error captureCanvas(tTJSVariant *result, tjs_int, tTJSVariant **,
                                   iTJSDispatch2 *) {
        if(result) {
            *result = tTJSVariant((tjs_int)0);
        }
        return TJS_S_OK;
    }

    static tjs_error unloadUnusedTextures(tTJSVariant *result, tjs_int,
                                          tTJSVariant **, iTJSDispatch2 *) {
        if(result) {
            *result = tTJSVariant((tjs_int)0);
        }
        return TJS_S_OK;
    }

private:
    iTJSDispatch2 *window_ = nullptr;
    tjs_int width_ = 0;
    tjs_int height_ = 0;
    tjs_real halfWidth_ = 0.0;
    tjs_real halfHeight_ = 0.0;
};

} // namespace motion
