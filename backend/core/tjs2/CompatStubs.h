#pragma once
#include "tjsNative.h"

extern bool TVPEnableCompatStubs;

// Forward declaration
namespace TJS {
    class tTJSCustomObject;
}

bool TVPCheckCompatStub(TJS::tTJSCustomObject* obj, const tjs_char* membername, tTJSVariant* result);
