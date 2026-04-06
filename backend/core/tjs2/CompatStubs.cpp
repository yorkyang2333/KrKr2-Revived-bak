#include "tjsCommHead.h"
#include "CompatStubs.h"
#include "tjsArray.h"
#include "tjsDictionary.h"
#include "tjsObject.h"
#include <spdlog/spdlog.h>

bool TVPEnableCompatStubs = true;

namespace {

tTJSVariant TVPCreateCompatArray() {
    iTJSDispatch2 *array = TJSCreateArrayObject();
    tTJSVariant result(array, array);
    array->Release();
    return result;
}

tTJSVariant TVPCreateCompatMotionObject() {
    iTJSDispatch2 *obj = TJSCreateDictionaryObject();
    tTJSVariant result(obj, obj);
    tTJSVariant zeroInt((tjs_int)0);
    tTJSVariant zeroReal((tjs_real)0.0);
    tTJSVariant emptyArray = TVPCreateCompatArray();

    obj->PropSet(TJS_MEMBERENSURE, TJS_W("motion"), nullptr, &result, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("count"), nullptr, &zeroInt, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("outline"), nullptr, &zeroInt, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("loopTime"), nullptr, &zeroReal, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("variableKeys"), nullptr, &emptyArray,
                 obj);
    obj->Release();
    return result;
}

bool TVPCheckGenericCompatStub(const tjs_char *membername,
                               tTJSVariant *result) {
    if(!membername) {
        return false;
    }

    if(!TJS_strcmp(membername, TJS_W("captureCanvas")) ||
       !TJS_strcmp(membername, TJS_W("unloadUnusedTextures")) ||
       !TJS_strcmp(membername, TJS_W("registerExEvent")) ||
       !TJS_strcmp(membername, TJS_W("unRegisterExEvent"))) {
        if(result) {
            *result = tTJSVariant((tjs_int)0);
        }
        return true;
    }

    if(!TJS_strcmp(membername, TJS_W("D3DAdaptor"))) {
        if(result) {
            *result = tTJSVariant((tjs_int)0);
        }
        return true;
    }

    if(!TJS_strcmp(membername, TJS_W("motion"))) {
        if(result) {
            *result = TVPCreateCompatMotionObject();
        }
        return true;
    }

    if(!TJS_strcmp(membername, TJS_W("count")) ||
       !TJS_strcmp(membername, TJS_W("outline")) ||
       !TJS_strcmp(membername, TJS_W("freeMemory"))) {
        if(result) {
            *result = tTJSVariant((tjs_int)0);
        }
        return true;
    }

    if(!TJS_strcmp(membername, TJS_W("loopTime"))) {
        if(result) {
            *result = tTJSVariant((tjs_real)0.0);
        }
        return true;
    }

    if(!TJS_strcmp(membername, TJS_W("variableKeys"))) {
        if(result) {
            *result = TVPCreateCompatArray();
        }
        return true;
    }

    return false;
}

} // namespace

bool TVPCheckCompatStub(TJS::tTJSCustomObject* obj, const tjs_char* membername, tTJSVariant* result) {
    if (!TVPEnableCompatStubs || !obj || !membername) return false;

    if(TVPCheckGenericCompatStub(membername, result)) {
        spdlog::debug("CompatStub: Stubbed {}", ttstr(membername).AsStdString());
        return true;
    }

    // Check Window
    if (TJS_SUCCEEDED(obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("Window"), obj))) {
        if (!TJS_strcmp(membername, TJS_W("captureCanvas")) ||
            !TJS_strcmp(membername, TJS_W("registerExEvent")) ||
            !TJS_strcmp(membername, TJS_W("unRegisterExEvent")) ||
            !TJS_strcmp(membername, TJS_W("unloadUnusedTextures"))) {
            if (result) *result = tTJSVariant((tjs_int)0);
            spdlog::debug("CompatStub: Stubbed Window.{}", ttstr(membername).AsStdString());
            return true;
        }
        return false;
    }
    
    // Check Layer
    if (TJS_SUCCEEDED(obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("Layer"), obj))) {
        if (!TJS_strcmp(membername, TJS_W("outline")) ||
            !TJS_strcmp(membername, TJS_W("freeMemory"))) {
            if (result) *result = tTJSVariant((tjs_int)0);
            spdlog::debug("CompatStub: Stubbed Layer.{}", ttstr(membername).AsStdString());
            return true;
        }
        return false;
    }

    // Check System
    if (TJS_SUCCEEDED(obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("System"), obj))) {
        if (!TJS_strcmp(membername, TJS_W("createAppLock")) ||
            !TJS_strcmp(membername, TJS_W("doCompact")) ||
            !TJS_strcmp(membername, TJS_W("unloadUnusedTextures"))) {
            if (result) *result = tTJSVariant((tjs_int)0);
            spdlog::debug("CompatStub: Stubbed System.{}", ttstr(membername).AsStdString());
            return true;
        }
        return false;
    }
    
    return false;
}
