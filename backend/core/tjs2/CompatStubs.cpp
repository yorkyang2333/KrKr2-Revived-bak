#include "tjsCommHead.h"
#include "CompatStubs.h"
#include "tjsObject.h"
#include <spdlog/spdlog.h>

bool TVPEnableCompatStubs = true;

bool TVPCheckCompatStub(TJS::tTJSCustomObject* obj, const tjs_char* membername, tTJSVariant* result) {
    if (!TVPEnableCompatStubs || !obj || !membername) return false;

    // Check Window
    if (TJS_SUCCEEDED(obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("Window"), obj))) {
        if (!TJS_strcmp(membername, TJS_W("captureCanvas")) ||
            !TJS_strcmp(membername, TJS_W("registerExEvent")) ||
            !TJS_strcmp(membername, TJS_W("unRegisterExEvent"))) {
            if (result) *result = tTJSVariant();
            spdlog::debug("CompatStub: Stubbed Window.{}", ttstr(membername).AsStdString());
            return true;
        }
        return false;
    }
    
    // Check Layer
    if (TJS_SUCCEEDED(obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("Layer"), obj))) {
        if (!TJS_strcmp(membername, TJS_W("outline")) ||
            !TJS_strcmp(membername, TJS_W("freeMemory"))) {
            if (result) *result = tTJSVariant();
            spdlog::debug("CompatStub: Stubbed Layer.{}", ttstr(membername).AsStdString());
            return true;
        }
        return false;
    }

    // Check System
    if (TJS_SUCCEEDED(obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("System"), obj))) {
        if (!TJS_strcmp(membername, TJS_W("createAppLock")) ||
            !TJS_strcmp(membername, TJS_W("doCompact"))) {
            if (result) *result = tTJSVariant();
            spdlog::debug("CompatStub: Stubbed System.{}", ttstr(membername).AsStdString());
            return true;
        }
        return false;
    }
    
    return false;
}
